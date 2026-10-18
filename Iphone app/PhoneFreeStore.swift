//
//  PhoneFreeStore.swift
//  Iphone app
//
//  Everything the app knows, in one place.
//
//  The app is built around a single, always-on number: how long it has been
//  since you last used your phone. That number is the home screen's hero, it is
//  what the Lock Screen counter counts up, and it is what the "are you sure?"
//  gate is protecting. A goal is a way of protecting that number deliberately;
//  it is not the only thing the app measures.
//
//  Because the app is aimed at people with OCD and ADHD, the rules here are
//  deliberately boring and predictable: one streak, no punishment for a broken
//  one, and honest numbers.
//

import Foundation
import Observation
import UIKit
import WidgetKit

// MARK: - Events

/// A single thing that happened. Kept plain and verbal so the history reads
/// like a diary rather than a database.
struct PhoneFreeEvent: Codable, Identifiable, Hashable {
    var id = UUID()
    var timestamp: Date
    var kind: String
    var note: String?
    var duration: TimeInterval?
}

/// The app's tiny haptic vocabulary. Named by intent rather than by feel, so
/// the same action always feels the same as screens change.
nonisolated enum PhoneFreeHaptic {
    /// Picking between options — light and near-imperceptible.
    case selection
    /// A gentle acknowledgement.
    case light
    /// Something worth noticing.
    case medium
    /// Something earned. Reserved for wins, so it keeps its meaning.
    case success
}

nonisolated enum PhoneFreeEventKind {
    static let goalStarted = "goal_started"
    static let goalCompleted = "goal_completed"
    static let goalEnded = "goal_ended"
    static let pickup = "reach"
}

/// One day's protected time, shaped for Swift Charts.
struct PhoneFreeDayStat: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let seconds: TimeInterval
}

// MARK: - Store

@Observable
final class PhoneFreeStore {

    static let appGroupID = "group.com.danielebuatti.phonefree"

    /// Remembers when the phone was last in hand across launches, so an
    /// absence PhoneFree slept (or was killed) through is not mistaken for
    /// time on the phone. See `closeSessionInterruptedByLock(at:)`.
    private static let backgroundedAtKey = "phoneFreeLastSeenAt"

    /// Durations offered on the home screen. Short, clear, few.
    let goalOptions = [5, 10, 20, 30, 45]

    // MARK: Feedback
    //
    // One consistent set of taps. Touch is the fastest feedback the brain can
    // read, which is why every meaningful action here has a haptic.

    /// Bumped on every tap so the shell can fire `sensoryFeedback`.
    var hapticCount = 0

    /// The most recent tap, read by the shell to choose the sensation.
    private(set) var lastHaptic: PhoneFreeHaptic?

    func play(_ haptic: PhoneFreeHaptic) {
        lastHaptic = haptic
        hapticCount += 1
    }

    // MARK: State

    var events: [PhoneFreeEvent] = []
    var selectedMinutes = 20

    var goalStart: Date?
    var goalEnd: Date?
    var goalActive = false

    var plan: [PlannedActivity] = []
    var reflections: [PhoneFreeReflection] = []
    var windows: [PhoneFreeWindow] = []

    /// Where the away counter counts from, and whether the phone is being
    /// used right now. Shared with the Shortcuts actions and the widget, so it
    /// lives in `PhoneFreeUsage` and is persisted through it.
    var usage = PhoneFreeUsage.State()

    /// Where the current stretch away counts from.
    var lastCheckIn: Date? {
        get { usage.lastCheckIn }
        set { usage.lastCheckIn = newValue }
    }

    /// Seconds of use before the counter resets. Chosen in Settings.
    var resetAfter: TimeInterval {
        get { usage.resetAfter }
        set {
            usage.resetAfter = newValue
            save()
        }
    }

    /// The live away counter on the Lock Screen and in the Dynamic Island.
    /// Kept in the shared defaults, because the Shortcuts actions read it too.
    var liveCounterEnabled = PhoneFreeLiveActivityManager.liveCounterEnabled {
        didSet {
            PhoneFreeUsage.defaults?.set(
                liveCounterEnabled,
                forKey: PhoneFreeLiveActivityManager.liveCounterKey
            )
            syncLockScreenCounter()
        }
    }

    /// Repeating Lock Screen reminders while a goal runs. Chosen in Settings.
    var goalNudgesEnabled = true {
        didSet {
            guard didLoad else { return }
            save()
            rescheduleGoalAlerts()
        }
    }

    /// A bell when a goal finishes. Chosen in Settings.
    var finishChimeEnabled = true {
        didSet {
            guard didLoad else { return }
            save()
            rescheduleGoalAlerts()
        }
    }

    /// A bell at the end of each task in a plan, so a change of activity is
    /// felt rather than discovered. Chosen in Settings.
    var taskChimeEnabled = true {
        didSet {
            guard didLoad else { return }
            save()
            rescheduleGoalAlerts()
        }
    }

    /// Whether the bell sounds through the Ring/Silent switch. Off, it follows
    /// the switch like every other app. Chosen in Settings.
    var chimeOverridesSilent = true {
        didSet {
            guard didLoad else { return }
            save()
        }
    }

    /// How progress towards a goal or the next target is drawn. Purely how it
    /// looks — the numbers and the rules do not change. Chosen in Settings.
    var progressStyle: PhoneFreeProgressStyle = .water {
        didSet {
            guard didLoad else { return }
            save()
        }
    }

    /// Plays the completion bell, if the user wants it. Called when a timer
    /// finishes while the app is open; the notification carries it when it is
    /// not.
    func playFinishChime() {
        guard finishChimeEnabled else { return }
        PhoneFreeAudio.shared.play(overrideSilent: chimeOverridesSilent)
    }

    /// Plays the bell no matter what, so Settings can let the user hear it
    /// while they are still deciding.
    func previewChime() {
        PhoneFreeAudio.shared.play(overrideSilent: chimeOverridesSilent)
    }

    // MARK: Introduction

    /// Shown on first launch, and again whenever Settings asks for it.
    var showingOnboarding = false

    func finishOnboarding() {
        showingOnboarding = false
        PhoneFreeUsage.defaults?.set(true, forKey: "phoneFreeOnboarded")
    }

    // MARK: Gate presentation

    var showingPromiseGate = false
    var showingCheckInGate = false
    var checkInGateGap: TimeInterval = 0

    private var promiseGateShownThisSession = false

    /// `true` while PhoneFree is on screen. The app being open is the one use
    /// signal that is never in doubt, so while this is set the counter is
    /// always frozen — however long the visit, whatever is on screen.
    private var isInForeground = false
    private var lastCheckInGateShownAt: Date?
    private var didLoad = false

    /// When PhoneFree last left the foreground. It is the last moment the app
    /// can be sure the phone was still being held, so it is where a session
    /// broken by an unobserved lock is closed.
    private var backgroundedAt: Date?

    /// `true` once the device has been seen locked during the current absence.
    /// iOS does not deliver the lock signal to a suspended app, so an open
    /// session can survive a lock — this is what lets the unlock put it right.
    private var wasLockedWhileAway = false

    /// Watches the lock state itself for a little while after the app leaves
    /// the screen, for the one lock signal iOS swallows (see
    /// `startLockWatchdog`).
    @ObservationIgnored private var lockWatchdogTask: Task<Void, Never>?

    /// The background-execution assertion that keeps the watchdog awake; iOS
    /// would otherwise suspend the app seconds after it leaves the screen.
    @ObservationIgnored private var lockWatchdogAssertion: UIBackgroundTaskIdentifier = .invalid

    /// Below this, opening the app is just the app; it is not worth friction.
    private let checkInGateThreshold: TimeInterval = 60

    /// Above this, the user was plainly away (asleep, at work) and friction
    /// would be nagging rather than useful.
    private let checkInGateMaxGap: TimeInterval = 6 * 3600

    init() {
        load()
    }

    // MARK: - Lifecycle

    /// Called when the app appears and whenever it comes back to the front.
    func handleBecameActive() {
        // The app is awake again, so the watchdog has nothing left to catch.
        stopLockWatchdog()

        // The Shortcuts actions may have changed the counter while the app
        // was in the background.
        reloadUsage()

        // If the device was locked while PhoneFree was suspended, the "put
        // down" signal never arrived and an open session is still on the
        // books. Close it before anything reads the number. Done here as well
        // as on unlock, because the two signals can arrive in either order.
        closeSessionInterruptedByLock(at: Date())

        // No bell here: a goal that ended while the app was closed has already
        // rung its notification, and ringing again on the way back in would be
        // a double.
        finishExpiredGoalIfNeeded(chime: false)

        let now = Date()
        logPickup(at: now)

        // Having the app open *is* using the phone — with or without a goal.
        // The counter freezes, and resets if this goes on past the grace
        // period. The number the gate shows is read first, so it is the
        // stretch the user is about to put at risk.
        let gap = usage.awayInterval(at: now)

        isInForeground = true
        usage.beginUse(at: now)
        save()

        if goalActive {
            guard let end = goalEnd, end > now else { return }

            if !promiseGateShownThisSession {
                promiseGateShownThisSession = true
                showingPromiseGate = true
            }

            return
        }

        // Never stack the gate on top of an open reflection sheet, or behind
        // the introduction — leaving to set up Shortcuts is not "away".
        guard !showingReflectionSheet, !showingOnboarding else { return }

        guard gap >= checkInGateThreshold, gap <= checkInGateMaxGap else {
            return
        }

        // Don't ask again within a minute of asking. Quick app switching
        // should not turn into a loop of the same question.
        if let lastAsked = lastCheckInGateShownAt,
           now.timeIntervalSince(lastAsked) < 60 {
            return
        }

        lastCheckInGateShownAt = now
        checkInGateGap = gap
        showingCheckInGate = true
    }

    /// Called when the app leaves the front, so the gates can appear again the
    /// next time it is opened. That repeat is the point.
    ///
    /// Leaving the screen is only a "put down" signal if the device is
    /// actually *locked*. If it is still unlocked, the user has just switched
    /// apps or gone to the Home Screen — they are still using the phone, so
    /// the use session stays open: the counter keeps freezing, and resets
    /// after the grace period, exactly as it does while PhoneFree is on
    /// screen. Only a locked device ends the session and starts the counter
    /// counting the time away again.
    func handleResignedActive() {
        promiseGateShownThisSession = false
        isInForeground = false

        // Whatever the last absence was watching for, this one starts fresh.
        stopLockWatchdog()

        let now = Date()
        backgroundedAt = now
        wasLockedWhileAway = false

        if UIApplication.shared.isProtectedDataAvailable {
            // Still unlocked: still in use. The session stays open, so the
            // counter freezes rather than counting up. There is now other-app
            // time at stake, so the countdown reminders run it home.
            if usage.hasStretchAtStake {
                PhoneFreeUseReminders.schedule(for: usage, now: now)
            }

            // A lock landing in the next few seconds would otherwise be
            // invisible to an app the user has just left.
            if usage.isUsing(at: now) {
                startLockWatchdog()
            }
        } else {
            // Locked: the phone went down. The counter starts again — or
            // carries on, if this was inside the grace period.
            wasLockedWhileAway = true
            usage.endUse(at: now)
            PhoneFreeUseReminders.cancel()
        }

        save()
        syncLockScreenCounter()
    }

    /// The device locked. This is the real "put down" signal, wherever the
    /// app happens to be, so the use session ends and the counter starts
    /// counting the time away again from this moment.
    func handleDeviceLocked() {
        stopLockWatchdog()

        let now = Date()
        wasLockedWhileAway = true
        backgroundedAt = backgroundedAt ?? now
        usage.endUse(at: now)
        PhoneFreeUseReminders.cancel()
        save()
        syncLockScreenCounter()
    }

    /// The device unlocked: the phone is back in hand. The use session
    /// starts so the counter freezes — but `lastCheckIn` is left untouched,
    /// so the away gap the check-in gate reports is still the honest one.
    func handleDeviceUnlocked() {
        stopLockWatchdog()

        let now = Date()

        // An unlock proves a lock happened, and the lock may have come while
        // PhoneFree was suspended and could not see it. Close any session that
        // outlived the last moment the app saw the user, so the locked stretch
        // counts as time away rather than time on the phone. Without this, a
        // stretch the Lock Screen was happily counting up is thrown away the
        // instant the app is opened.
        wasLockedWhileAway = true
        closeSessionInterruptedByLock(at: now)

        usage.beginUse(at: now)
        save()
        syncLockScreenCounter()
    }

    // MARK: - The lock watchdog

    /// Catches the lock signal iOS withholds.
    ///
    /// A lock that happens while PhoneFree is suspended is never delivered on
    /// the way in, and the app is suspended a few seconds after it leaves the
    /// screen — exactly when someone pockets and locks the phone. So for that
    /// short window the app holds a background assertion and reads the device's
    /// lock state itself, which turns the usual case into an exact lock moment
    /// rather than a guess made on the way back in.
    ///
    /// Nothing here changes what a plain app switch does: the state only ever
    /// goes from available to unavailable, and it stays available for someone
    /// who is still holding the phone.
    private func startLockWatchdog() {
        stopLockWatchdog()

        let assertion = UIApplication.shared.beginBackgroundTask(
            withName: "PhoneFreeLockWatchdog"
        ) { [weak self] in
            // Out of time. Stop watching; whatever the session looks like now
            // is what the resume path has to work with.
            Task { @MainActor in self?.stopLockWatchdog() }
        }

        guard assertion != .invalid else { return }
        lockWatchdogAssertion = assertion

        lockWatchdogTask = Task { @MainActor in
            let deadline = Date().addingTimeInterval(25)

            while Date() < deadline, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                if Task.isCancelled { return }

                if !UIApplication.shared.isProtectedDataAvailable {
                    handleDeviceLocked()
                    return
                }
            }

            stopLockWatchdog()
        }
    }

    private func stopLockWatchdog() {
        lockWatchdogTask?.cancel()
        lockWatchdogTask = nil

        if lockWatchdogAssertion != .invalid {
            UIApplication.shared.endBackgroundTask(lockWatchdogAssertion)
            lockWatchdogAssertion = .invalid
        }
    }

    /// Closes a use session that is still open even though the device has
    /// been locked since — the "put down" signal PhoneFree never received.
    ///
    /// The lock moment itself is unknowable from here, so the session is
    /// closed at the last moment the app saw the user, which is the generous
    /// reading: everything after that counts as time away.
    ///
    /// A lock is proof. Failing one, the hourglass is the fallback: once the
    /// app has been off screen for longer than the whole shield the session was
    /// running on, the session is holding nothing back — the grace it was
    /// protecting has already gone — and the honest reading is that the phone
    /// was down, which is what the Lock Screen has been showing all along. A
    /// short switch to another app stays inside that shield and keeps its
    /// session exactly as before.
    private func closeSessionInterruptedByLock(at now: Date) {
        guard let backgroundedAt,
              let usingSince = usage.usingSince,
              usingSince <= backgroundedAt,
              usage.isUsing(at: now) else { return }

        let shield = usage.resetAfter + usage.surplus
        let interrupted = wasLockedWhileAway
            || now.timeIntervalSince(backgroundedAt) >= shield

        guard interrupted else { return }

        usage.endUse(at: max(usingSince, backgroundedAt))
    }

    /// Re-reads the counter that the Shortcuts actions share with the app.
    ///
    /// While the app is on screen its own session wins: a Shortcuts "I put my
    /// phone down" that lands as someone switches *into* PhoneFree must not
    /// start the counter while they are looking at it.
    func reloadUsage() {
        let now = Date()
        var shared = PhoneFreeUsage.load().settled(at: now)

        if isInForeground {
            if usage.isUsing(at: now), !shared.isUsing(at: now) {
                shared.lastCheckIn = usage.lastCheckIn
                shared.usingSince = usage.usingSince
            }
            shared.beginUse(at: now)
        }

        if shared != usage {
            usage = shared
            save()
        }
    }

    /// The goal's own clock runs down whether or not the app is open. While
    /// the app is open, the use session is kept fresh so a long visit is never
    /// mistaken for an abandoned one.
    func tick() {
        chimeForFinishedTask()
        finishExpiredGoalIfNeeded()

        guard isInForeground else { return }

        let before = usage
        usage.keepAlive(at: Date())

        if usage != before {
            save()
        }
    }

    /// The last moment `tick` ran, so a task boundary can be spotted as it is
    /// crossed rather than depended on to fall on a whole second.
    @ObservationIgnored private var lastTickAt: Date?

    /// Rings the bell as each planned task ends, while the app is open. When
    /// the app is suspended — the usual case while a goal runs — the matching
    /// notification carries the same bell instead.
    private func chimeForFinishedTask() {
        let now = Date()
        defer { lastTickAt = now }

        guard taskChimeEnabled, finishChimeEnabled,
              goalActive, !plan.isEmpty,
              let lastTick = lastTickAt,
              now.timeIntervalSince(lastTick) < 5,
              let end = goalEnd else { return }

        var cursor = goalStart ?? end

        for planned in plan {
            guard planned.activity != nil else { continue }

            let segmentEnd = cursor.addingTimeInterval(
                TimeInterval(planned.minutes * 60)
            )
            cursor = segmentEnd

            // The last task's end is the whole goal's own bell, not a task one.
            guard segmentEnd < end - 0.5 else { break }

            if segmentEnd > lastTick, segmentEnd <= now {
                playFinishChime()
                return
            }
        }
    }

    // MARK: - Goal actions

    func startGoal() {
        let minutes = effectiveGoalMinutes

        startGoal(
            minutes: minutes,
            note: plan.isEmpty
                ? "\(minutes)-minute goal"
                : "\(minutes)-minute plan (\(plan.count) activities)"
        )
    }

    /// The single place a goal actually begins, so a plain goal and one opened
    /// from a window reminder cannot drift apart.
    private func startGoal(minutes: Int, note: String) {
        guard !goalActive else { return }

        play(.medium)

        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))

        goalStart = now
        goalEnd = end
        goalActive = true

        // Starting a goal is itself a promise to stop using the phone, so the
        // streak clock starts again — from the moment the phone goes down. The
        // app is still open, so until then it holds at zero.
        usage.restart(at: now)
        if isInForeground {
            usage.beginUse(at: now)
        }
        PhoneFreeUseReminders.cancel()

        events.append(
            PhoneFreeEvent(
                timestamp: now,
                kind: PhoneFreeEventKind.goalStarted,
                note: note,
                duration: nil
            )
        )

        save()

        PhoneFreeLiveActivityManager.shared.start(
            minutes: minutes,
            start: now,
            end: end,
            segments: buildSegments(from: now)
        )

        // The nudges need permission. Asking here, as the goal starts, is
        // when the reason is obvious; iOS only shows the prompt once.
        Task {
            _ = await PhoneFreeWindowScheduler.shared.requestAuthorization()
            rescheduleGoalAlerts()
        }
    }

    /// Called when the user taps a phone-free window reminder. They have
    /// already said yes, so the gates that ask them to think twice are skipped.
    ///
    /// When the tap lands inside the window, the goal runs until the window
    /// ends — "no phone 22:00 – 07:00" should mean exactly that. A stale
    /// reminder falls back to whatever length the screen was last set to.
    func startGoalFromReminder(windowID: String?) {
        showingCheckInGate = false
        showingPromiseGate = false

        // They are not being asked about ending anything — they are starting.
        promiseGateShownThisSession = true

        guard !goalActive else { return }

        let window = windowID
            .flatMap(UUID.init(uuidString:))
            .flatMap { id in windows.first(where: { $0.id == id }) }

        if let window, let end = window.endIfInside(at: Date()) {
            startGoal(
                minutes: max(1, Int(end.timeIntervalSinceNow / 60)),
                note: window.displayName
                    + " · until "
                    + end.formatted(date: .omitted, time: .shortened)
            )
            return
        }

        startGoal()
    }

    /// Asked for by the "End goal early" button. Shows friction rather than
    /// ending anything.
    func requestEndGoal() {
        guard goalActive else { return }
        play(.light)
        showingPromiseGate = true
    }

    /// "Keep going" — dismiss the promise gate and carry on.
    func keepGoing() {
        play(.success)
        showingPromiseGate = false
    }

    /// Confirmed end of the promise. The time already protected still counts.
    func breakPromise() {
        guard goalActive, let start = goalStart else { return }

        play(.medium)

        let now = Date()
        let protected = max(0, now.timeIntervalSince(start))

        events.append(
            PhoneFreeEvent(
                timestamp: now,
                kind: PhoneFreeEventKind.goalEnded,
                note: "Ended early",
                duration: protected
            )
        )

        goalActive = false
        goalStart = nil
        goalEnd = nil
        showingPromiseGate = false

        // They are using the phone now, so the streak clock restarts — and,
        // since the app is open, it is held at zero until they put it down.
        usage.restart(at: now)
        usage.beginUse(at: now)

        // The time protected before they stopped still earns free time. Effort
        // is never thrown away — that is the whole point of reward over shame.
        award(usage.creditSurplus(protected))

        save()

        PhoneFreeLiveActivityManager.shared.end()
        PhoneFreeGoalNudges.cancel()
        PhoneFreeGoalChimes.cancel()
        syncLockScreenCounter()

        requestReflectionIfPlanned()
    }

    /// The goal ran all the way out. Handled on the next tick or launch, since
    /// the app is usually suspended when it happens.
    ///
    /// - Parameter chime: whether to ring the in-app bell. It is on for the
    ///   foreground tick, where the bell is the only alert, and off when the
    ///   completion is discovered on the way back in, where it would double the
    ///   notification that already rang.
    func finishExpiredGoalIfNeeded(chime: Bool = true) {
        guard goalActive, let end = goalEnd, Date() >= end else { return }

        play(.success)
        if chime { playFinishChime() }

        let start = goalStart ?? end
        let protected = end.timeIntervalSince(start)

        events.append(
            PhoneFreeEvent(
                timestamp: end,
                kind: PhoneFreeEventKind.goalCompleted,
                note: "\(max(1, Int((protected / 60).rounded())))-minute goal",
                duration: protected
            )
        )

        goalActive = false
        goalStart = nil
        goalEnd = nil

        // Finishing the goal banks free phone time, one minute for one.
        award(usage.creditSurplus(protected))

        // Deliberately *not* moving `lastCheckIn` here. The user has not
        // touched the phone yet — that is the moment the check-in gate should
        // greet them, and resetting now would throw the streak away.
        save()

        PhoneFreeLiveActivityManager.shared.end()
        PhoneFreeGoalNudges.cancel()
        PhoneFreeGoalChimes.cancel()
        syncLockScreenCounter()

        requestReflectionIfPlanned()
    }

    /// Rebuilds the goal's notifications from the current settings: the
    /// repeating nudges, and the bells at each task boundary and at the end.
    private func rescheduleGoalAlerts() {
        guard goalActive, let start = goalStart, let end = goalEnd else {
            PhoneFreeGoalNudges.cancel()
            PhoneFreeGoalChimes.cancel()
            return
        }

        if goalNudgesEnabled {
            PhoneFreeGoalNudges.schedule(start: start, end: end)
        } else {
            PhoneFreeGoalNudges.cancel()
        }

        if finishChimeEnabled {
            PhoneFreeGoalChimes.schedule(
                end: end,
                segments: taskChimeEnabled ? buildSegments(from: start) : []
            )
        } else {
            PhoneFreeGoalChimes.cancel()
        }
    }

    // MARK: - Surplus
    //
    // Free phone time earned by finishing phone-free goals. While it lasts it
    // pays for phone use past the grace period, so the counter stays frozen and
    // the streak survives. The reward is deliberately immediate and visible —
    // that is what makes it work for an ADHD brain.

    /// A just-earned amount, shown as a lime "＋N min" banner until it fades.
    /// `nil` when nothing was just earned.
    var surplusAward: TimeInterval?

    @ObservationIgnored private var surplusAwardToken = 0

    /// Free phone time banked, in seconds.
    var surplusSeconds: TimeInterval { usage.surplus }

    /// Free time left once the open session's use is paid for.
    func surplusRemaining(at date: Date = Date()) -> TimeInterval {
        usage.surplusRemaining(at: date)
    }

    /// `true` while banked free time is shielding the current session.
    func isShielded(at date: Date = Date()) -> Bool {
        usage.isShielded(at: date)
    }

    /// The bank's ceiling, in seconds — for the "full" indication in the UI.
    var surplusCap: TimeInterval { PhoneFreeUsage.maxSurplus }

    /// Shows the "＋N min free time" banner and clears it a few seconds later.
    private func award(_ seconds: TimeInterval) {
        guard seconds >= 60 else { return }

        let wholeMinutes = max(1, Int((seconds / 60).rounded()))
        surplusAward = TimeInterval(wholeMinutes * 60)
        surplusAwardToken += 1
        let token = surplusAwardToken

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard surplusAwardToken == token else { return }
            surplusAward = nil
        }
    }

    func dismissSurplusAward() {
        surplusAwardToken += 1
        surplusAward = nil
    }

    // MARK: - Check-in gate

    /// "Use it anyway" — the gate goes, and the grace period that began when
    /// the app opened keeps running. Nothing is reset yet: the reset happens
    /// only if they are still on the phone when it runs out.
    func confirmPhoneUse() {
        play(.light)
        showingCheckInGate = false
    }

    /// "I'll put it down" — the gate goes. Nothing else changes yet: the
    /// phone is still in their hand. The counter carries on the moment they
    /// lock it or leave the app, inside the grace period.
    func putItDown() {
        play(.light)
        showingCheckInGate = false
    }

    // MARK: - Reflections

    func requestReflectionIfPlanned() {
        guard !plan.isEmpty else { return }
        pendingReflection = plan
        showingReflectionSheet = true
    }

    var pendingReflection: [PlannedActivity] = []
    var showingReflectionSheet = false

    func addReflections(_ newReflections: [PhoneFreeReflection]) {
        reflections.append(contentsOf: newReflections)
        showingReflectionSheet = false
        save()
    }

    func skipReflections() {
        showingReflectionSheet = false
    }

    // MARK: - Plan

    func setPlan(_ newPlan: [PlannedActivity]) {
        plan = newPlan
        save()
    }

    func clearPlan() {
        play(.light)
        plan = []
        save()
    }

    var planTotalMinutes: Int {
        plan.reduce(0) { $0 + $1.minutes }
    }

    /// The length of the goal: the plan's total when there is a plan, otherwise
    /// whatever the duration chips say.
    var effectiveGoalMinutes: Int {
        plan.isEmpty ? selectedMinutes : max(planTotalMinutes, 1)
    }

    /// The length of the goal that is actually running. Differs from
    /// `effectiveGoalMinutes` when a window reminder started it ("until
    /// 07:00"), so screens must use this once a goal has begun.
    var runningGoalMinutes: Int {
        guard let start = goalStart, let end = goalEnd else {
            return effectiveGoalMinutes
        }
        return max(1, Int((end.timeIntervalSince(start) / 60).rounded()))
    }

    /// Turns the plan into the timed segments the Live Activity renders. Each
    /// one starts where the previous ended.
    func buildSegments(from start: Date) -> [PhoneFreeActivitySegment] {
        var cursor = start

        return plan.compactMap { planned in
            guard let activity = planned.activity else { return nil }

            let segmentEnd = cursor.addingTimeInterval(
                TimeInterval(planned.minutes * 60)
            )

            let segment = PhoneFreeActivitySegment(
                name: activity.name,
                symbol: activity.symbol,
                start: cursor,
                end: segmentEnd
            )

            cursor = segmentEnd

            return segment
        }
    }

    /// Which planned activity should be showing now, and when it ends.
    func currentActivity(
        at date: Date
    ) -> (activity: PhoneFreeActivity, end: Date)? {
        guard let start = goalStart else { return nil }

        var cursor = start

        for planned in plan {
            guard let activity = planned.activity else { continue }

            let end = cursor.addingTimeInterval(
                TimeInterval(planned.minutes * 60)
            )

            if date < end {
                return (activity, end)
            }

            cursor = end
        }

        return nil
    }

    var suggestedActivities: [PhoneFreeActivity] {
        PhoneFreeAdvisor.suggestions(from: reflections)
    }

    // MARK: - The number that matters

    /// How long since the user last used the phone. Frozen while the phone
    /// is in use, and zero once that use has run past the grace period.
    func awayInterval(at date: Date = Date()) -> TimeInterval {
        usage.awayInterval(at: date)
    }

    /// `true` while the phone is being used and the counter is frozen.
    func isUsingPhone(at date: Date = Date()) -> Bool {
        !goalActive && usage.isUsing(at: date)
    }

    /// `true` when the grace-period countdown is worth showing: the phone is
    /// in use and there is at least a minute of stretch at stake.
    func showsResetCountdown(at date: Date = Date()) -> Bool {
        isUsingPhone(at: date) && usage.hasStretchAtStake
    }

    /// Where the goal has got to, for the progress ring.
    func goalProgress(at date: Date) -> Double {
        guard goalActive, let start = goalStart, let end = goalEnd else {
            return 0
        }

        let total = max(end.timeIntervalSince(start), 1)
        let elapsed = date.timeIntervalSince(start)

        return min(max(elapsed / total, 0), 1)
    }

    func goalRemaining(at date: Date) -> TimeInterval {
        guard goalActive, let end = goalEnd else { return 0 }
        return max(0, end.timeIntervalSince(date))
    }

    // MARK: - Stats

    var pickupsToday: Int {
        events.filter {
            $0.kind == PhoneFreeEventKind.pickup &&
            Calendar.current.isDateInToday($0.timestamp)
        }.count
    }

    var completedGoalsToday: Int {
        events.filter {
            $0.kind == PhoneFreeEventKind.goalCompleted &&
            Calendar.current.isDateInToday($0.timestamp)
        }.count
    }

    var protectedSecondsToday: TimeInterval {
        events
            .filter {
                ($0.kind == PhoneFreeEventKind.goalCompleted ||
                 $0.kind == PhoneFreeEventKind.goalEnded) &&
                Calendar.current.isDateInToday($0.timestamp)
            }
            .reduce(0) { $0 + ($1.duration ?? 0) }
    }

    /// The longest stretch away from the phone today: either a finished one,
    /// or the one still running. Kept by the shared clock, so it always agrees
    /// with the counter the user is looking at.
    var bestGapToday: TimeInterval {
        max(usage.bestFinishedToday(at: Date()), awayInterval())
    }

    /// The longest stretch away, ever. Flattering, but true.
    var longestGapEver: TimeInterval {
        max(bestCompletedGapEver, awayInterval())
    }

    /// The longest stretch away that is *finished*. Excludes the run happening
    /// right now, so "is this a new record?" has an honest answer.
    var bestCompletedGapEver: TimeInterval {
        usage.bestEver
    }

    /// `true` when the stretch happening right now has already beaten every
    /// finished one. Guarded on `hasRecord` so a fresh install does not instantly
    /// declare a record on its first second of use.
    var isNewLongestGap: Bool {
        hasRecord && awayInterval() > bestCompletedGapEver
    }

    /// A record under a minute is noise, not an achievement — praising it
    /// would cheapen the real ones.
    var hasRecord: Bool {
        bestCompletedGapEver >= 60
    }

    // MARK: - Targets
    //
    // The ladder lives in `PhoneFreeTargets` so the app and the Lock Screen
    // widget always name the same next step.

    /// The next milestone the away counter is climbing towards.
    func nextGapTarget(at date: Date = Date()) -> TimeInterval? {
        PhoneFreeTargets.next(after: awayInterval(at: date))
    }

    /// How far the current gap has come towards its next milestone, `0...1`.
    func gapTargetProgress(at date: Date = Date()) -> Double {
        PhoneFreeTargets.progress(for: awayInterval(at: date))
    }

    /// How much longer until the next milestone. `nil` once the ladder's top
    /// rung is behind you.
    func gapTimeToTarget(at date: Date = Date()) -> TimeInterval? {
        guard let target = nextGapTarget(at: date) else { return nil }
        return max(0, target - awayInterval(at: date))
    }

    /// A "run" of consecutive days with at least one completed goal. Framed as
    /// a run, never as something to lose.
    var goalRunDays: Int {
        let calendar = Calendar.current

        let days = Set(
            events
                .filter { $0.kind == PhoneFreeEventKind.goalCompleted }
                .map { calendar.startOfDay(for: $0.timestamp) }
        )

        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())

        // The run may have ended yesterday and still be "alive" today.
        var cursor = days.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var run = 0

        while days.contains(cursor) {
            run += 1
            guard let previous = calendar.date(
                byAdding: .day,
                value: -1,
                to: cursor
            ) else { break }
            cursor = previous
        }

        return run
    }

    /// Protected time for each of the last `days` days, oldest first. Drives
    /// the chart on the Progress tab.
    func dailyProtected(days: Int) -> [PhoneFreeDayStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(
                byAdding: .day,
                value: -offset,
                to: today
            ) else { return nil }

            let seconds = events
                .filter {
                    ($0.kind == PhoneFreeEventKind.goalCompleted ||
                     $0.kind == PhoneFreeEventKind.goalEnded) &&
                    calendar.isDate($0.timestamp, inSameDayAs: day)
                }
                .reduce(0) { $0 + ($1.duration ?? 0) }

            return PhoneFreeDayStat(date: day, seconds: seconds)
        }
    }

    /// Today's events, newest first, with pickup noise removed.
    var todayHistory: [PhoneFreeEvent] {
        events
            .filter {
                $0.kind != PhoneFreeEventKind.pickup &&
                Calendar.current.isDateInToday($0.timestamp)
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Reflection insights, for the "what works for you" cards.
    var mostEnjoyed: PhoneFreeActivity? {
        PhoneFreeAdvisor.mostEnjoyed(from: reflections)
    }

    var hardest: PhoneFreeActivity? {
        PhoneFreeAdvisor.hardest(from: reflections)
    }

    // MARK: - The Lock Screen countdown

    /// Keeps the Lock Screen in step with the app.
    ///
    /// The Live Activity is now *only* for a running goal — it counts down and
    /// it expires after a few hours, which is what Live Activities are for. The
    /// always-on "since you last used your phone" counter lives on the Lock
    /// Screen widget instead: it never expires, it is not an App Review
    /// problem, and it does not make the app itself a reason to pick up the
    /// phone.
    ///
    /// Safe to call repeatedly — it refreshes an existing activity rather than
    /// stacking up new ones.
    func syncLockScreenCounter() {
        if goalActive,
           let start = goalStart,
           let end = goalEnd,
           end > Date() {
            PhoneFreeLiveActivityManager.shared.restoreIfNeeded(
                minutes: runningGoalMinutes,
                start: start,
                end: end,
                segments: buildSegments(from: start)
            )
            return
        }

        // No goal running: the Live Activity becomes the always-on away
        // counter, showing the same number as the widget and the app.
        let usage = usage
        Task {
            await PhoneFreeLiveActivityManager.shared.showAwayCounter(usage)
        }
    }

    // MARK: - Data

    /// The windows a fresh install starts with: the overnight one on, because
    /// night is where the most phone use happens, and lunch ready to switch on.
    private static func defaultWindows() -> [PhoneFreeWindow] {
        [
            PhoneFreeWindow(
                label: "Evening wind-down",
                startHour: 22,
                startMinute: 0,
                endHour: 7,
                endMinute: 0
            ),
            PhoneFreeWindow(
                enabled: false,
                label: "Lunch",
                startHour: 12,
                startMinute: 30,
                endHour: 13,
                endMinute: 15
            ),
        ]
    }

    func clearAllData() {
        events = []
        reflections = []
        plan = []
        windows = Self.defaultWindows()
        goalActive = false
        goalStart = nil
        goalEnd = nil
        usage.restart(at: Date())
        usage.surplus = 0
        surplusAward = nil

        save()
        PhoneFreeLiveActivityManager.shared.end()
        PhoneFreeGoalNudges.cancel()
        PhoneFreeGoalChimes.cancel()
        PhoneFreeUseReminders.cancel()
    }

    /// Forget today only. Useful for people who find a bad start hard to
    /// shake — a clean slate, not a punishment.
    func clearToday() {
        events.removeAll {
            Calendar.current.isDateInToday($0.timestamp)
        }

        goalActive = false
        goalStart = nil
        goalEnd = nil
        usage.restart(at: Date())
        usage.surplus = 0
        surplusAward = nil

        save()
        PhoneFreeLiveActivityManager.shared.end()
        PhoneFreeGoalNudges.cancel()
        PhoneFreeGoalChimes.cancel()
        PhoneFreeUseReminders.cancel()
        syncLockScreenCounter()
    }

    // MARK: - Pickups

    /// Every activation of the app is a pickup. It is a proxy — iOS gives apps
    /// no way to see real unlocks — but an honest one, and labelled as such.
    private func logPickup(at date: Date) {
        if let last = events.last(where: {
            $0.kind == PhoneFreeEventKind.pickup
        }), date.timeIntervalSince(last.timestamp) < 5 {
            return
        }

        events.append(
            PhoneFreeEvent(
                timestamp: date,
                kind: PhoneFreeEventKind.pickup,
                note: nil,
                duration: nil
            )
        )

        save()
    }

    // MARK: - Persistence

    private func load() {
        defer { didLoad = true }

        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else {
            lastCheckIn = Date()
            return
        }

        // Read back before the session, so an absence the app slept through —
        // or was killed during — still knows when the phone was last in hand.
        backgroundedAt = defaults.object(forKey: Self.backgroundedAtKey) as? Date

        if let data = defaults.data(forKey: "phoneFreeHistory"),
           let saved = try? JSONDecoder().decode(
               [PhoneFreeEvent].self,
               from: data
           ) {
            events = saved
        }

        if let data = defaults.data(forKey: "phoneFreePlan"),
           let saved = try? JSONDecoder().decode(
               [PlannedActivity].self,
               from: data
           ) {
            plan = saved
        }

        if let data = defaults.data(forKey: "phoneFreeReflections"),
           let saved = try? JSONDecoder().decode(
               [PhoneFreeReflection].self,
               from: data
           ) {
            reflections = saved
        }

        if let data = defaults.data(forKey: "phoneFreeWindows"),
           let saved = try? JSONDecoder().decode(
               [PhoneFreeWindow].self,
               from: data
           ) {
            windows = saved
        } else {
            // Nothing saved yet — start with the two windows most people mean
            // when they say "I'd like to stop using my phone at night".
            windows = Self.defaultWindows()
        }

        usage = PhoneFreeUsage.load()
        showingOnboarding = !defaults.bool(forKey: "phoneFreeOnboarded")

        // Records used to be worked out from app-open times. Carry the old
        // best over once, so upgrading never wipes someone's record.
        if usage.bestEver == 0 {
            let opens = events
                .filter { $0.kind == PhoneFreeEventKind.pickup }
                .map(\.timestamp)
                .sorted()

            for (previous, next) in zip(opens, opens.dropFirst()) {
                usage.bestEver = max(
                    usage.bestEver,
                    next.timeIntervalSince(previous)
                )
            }
        }

        if defaults.object(forKey: "phoneFreeGoalNudges") != nil {
            goalNudgesEnabled = defaults.bool(forKey: "phoneFreeGoalNudges")
        }

        if defaults.object(forKey: "phoneFreeFinishChime") != nil {
            finishChimeEnabled = defaults.bool(forKey: "phoneFreeFinishChime")
        }

        if defaults.object(forKey: "phoneFreeTaskChime") != nil {
            taskChimeEnabled = defaults.bool(forKey: "phoneFreeTaskChime")
        }

        if defaults.object(forKey: "phoneFreeChimeOverridesSilent") != nil {
            chimeOverridesSilent = defaults.bool(
                forKey: "phoneFreeChimeOverridesSilent"
            )
        }

        if let saved = defaults.string(forKey: "phoneFreeProgressStyle"),
           let style = PhoneFreeProgressStyle(rawValue: saved) {
            progressStyle = style
        }

        goalActive = defaults.bool(forKey: "phoneFreeGoalActive")

        if let timestamp = defaults.object(
            forKey: "phoneFreeGoalStart"
        ) as? Date {
            goalStart = timestamp
        }

        if let timestamp = defaults.object(
            forKey: "phoneFreeGoalEnd"
        ) as? Date {
            goalEnd = timestamp
        }

        if let start = goalStart, let end = goalEnd, end > start {
            selectedMinutes = max(1, Int(end.timeIntervalSince(start) / 60))
        }

        if !goalActive {
            goalStart = nil
            goalEnd = nil
        }

        // First run: start the clock now rather than at some imaginary zero.
        if lastCheckIn == nil {
            lastCheckIn = Date()
        }
    }

    func save() {
        guard didLoad else { return }
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else {
            return
        }

        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: "phoneFreeHistory")
        }

        if let data = try? JSONEncoder().encode(plan) {
            defaults.set(data, forKey: "phoneFreePlan")
        }

        if let data = try? JSONEncoder().encode(reflections) {
            defaults.set(data, forKey: "phoneFreeReflections")
        }

        if let data = try? JSONEncoder().encode(windows) {
            defaults.set(data, forKey: "phoneFreeWindows")
        }

        defaults.set(goalActive, forKey: "phoneFreeGoalActive")

        if let goalStart {
            defaults.set(goalStart, forKey: "phoneFreeGoalStart")
        } else {
            defaults.removeObject(forKey: "phoneFreeGoalStart")
        }

        if let goalEnd {
            defaults.set(goalEnd, forKey: "phoneFreeGoalEnd")
        } else {
            defaults.removeObject(forKey: "phoneFreeGoalEnd")
        }

        PhoneFreeUsage.save(usage)

        if let backgroundedAt {
            defaults.set(backgroundedAt, forKey: Self.backgroundedAtKey)
        }
        defaults.set(goalNudgesEnabled, forKey: "phoneFreeGoalNudges")
        defaults.set(finishChimeEnabled, forKey: "phoneFreeFinishChime")
        defaults.set(taskChimeEnabled, forKey: "phoneFreeTaskChime")
        defaults.set(
            chimeOverridesSilent,
            forKey: "phoneFreeChimeOverridesSilent"
        )
        defaults.set(progressStyle.rawValue, forKey: "phoneFreeProgressStyle")

        WidgetCenter.shared.reloadAllTimelines()
    }
}

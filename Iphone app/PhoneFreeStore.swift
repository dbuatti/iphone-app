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

    /// Durations offered on the home screen. Short, clear, few.
    let goalOptions = [5, 10, 20, 30, 45]

    // MARK: State

    var events: [PhoneFreeEvent] = []
    var selectedMinutes = 20

    var goalStart: Date?
    var goalEnd: Date?
    var goalActive = false

    var plan: [PlannedActivity] = []
    var reflections: [PhoneFreeReflection] = []

    /// The last moment the user *gave in* and used the phone. Everything the
    /// app shows counts up from here. Persisted.
    var lastCheckIn: Date?

    /// Whether the always-on counter is allowed on the Lock Screen.
    var lockScreenCounterEnabled = true

    // MARK: Gate presentation

    var showingPromiseGate = false
    var showingCheckInGate = false
    var checkInGateGap: TimeInterval = 0

    /// Set while the user is being shown *why* the timer restarted, so the home
    /// screen can say so once and then forget it.
    var justRestartedFrom: TimeInterval?

    private var promiseGateShownThisSession = false
    private var lastCheckInGateShownAt: Date?
    private var didLoad = false

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
        finishExpiredGoalIfNeeded()

        let now = Date()
        logPickup(at: now)

        if goalActive {
            guard let end = goalEnd, end > now else { return }

            if !promiseGateShownThisSession {
                promiseGateShownThisSession = true
                showingPromiseGate = true
            }

            return
        }

        // No goal running. This is the check-in moment.
        guard let last = lastCheckIn else {
            lastCheckIn = now
            save()
            return
        }

        // Never stack the gate on top of an open reflection sheet.
        guard !showingReflectionSheet else { return }

        let gap = now.timeIntervalSince(last)

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
    func handleResignedActive() {
        promiseGateShownThisSession = false
    }

    /// The goal's own clock runs down whether or not the app is open.
    func tick() {
        finishExpiredGoalIfNeeded()
    }

    // MARK: - Goal actions

    func startGoal() {
        guard !goalActive else { return }

        let minutes = effectiveGoalMinutes
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))

        goalStart = now
        goalEnd = end
        goalActive = true

        // Starting a goal is itself a promise to stop using the phone, so the
        // streak clock starts here.
        lastCheckIn = now

        events.append(
            PhoneFreeEvent(
                timestamp: now,
                kind: PhoneFreeEventKind.goalStarted,
                note: plan.isEmpty
                    ? "\(minutes)-minute goal"
                    : "\(minutes)-minute plan (\(plan.count) activities)",
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
    }

    /// Asked for by the "End goal early" button. Shows friction rather than
    /// ending anything.
    func requestEndGoal() {
        guard goalActive else { return }
        showingPromiseGate = true
    }

    /// "Keep going" — dismiss the promise gate and carry on.
    func keepGoing() {
        showingPromiseGate = false
    }

    /// Confirmed end of the promise. The time already protected still counts.
    func breakPromise() {
        guard goalActive, let start = goalStart else { return }

        let now = Date()

        events.append(
            PhoneFreeEvent(
                timestamp: now,
                kind: PhoneFreeEventKind.goalEnded,
                note: "Ended early",
                duration: max(0, now.timeIntervalSince(start))
            )
        )

        goalActive = false
        goalStart = nil
        goalEnd = nil
        showingPromiseGate = false

        // They are using the phone now, so the streak clock restarts.
        lastCheckIn = now

        save()

        PhoneFreeLiveActivityManager.shared.end()
        syncLockScreenCounter()

        requestReflectionIfPlanned()
    }

    /// The goal ran all the way out. Handled on the next tick or launch, since
    /// the app is usually suspended when it happens.
    func finishExpiredGoalIfNeeded() {
        guard goalActive, let end = goalEnd, Date() >= end else { return }

        let start = goalStart ?? end

        events.append(
            PhoneFreeEvent(
                timestamp: end,
                kind: PhoneFreeEventKind.goalCompleted,
                note: "\(effectiveGoalMinutes)-minute goal",
                duration: end.timeIntervalSince(start)
            )
        )

        goalActive = false
        goalStart = nil
        goalEnd = nil

        // Deliberately *not* moving `lastCheckIn` here. The user has not
        // touched the phone yet — that is the moment the check-in gate should
        // greet them, and resetting now would throw the streak away.
        save()

        PhoneFreeLiveActivityManager.shared.end()
        syncLockScreenCounter()

        requestReflectionIfPlanned()
    }

    // MARK: - Check-in gate

    /// "Use it anyway" — the user has decided to use the phone. The clock goes
    /// back to zero. Recorded so today's best is not quietly inflated.
    func confirmPhoneUse() {
        justRestartedFrom = checkInGateGap

        lastCheckIn = Date()
        showingCheckInGate = false

        save()
        syncLockScreenCounter()
    }

    /// "I'll put it down" — the streak survives. Nothing is recorded, because
    /// nothing was given up.
    func putItDown() {
        showingCheckInGate = false
    }

    func dismissRestartNotice() {
        justRestartedFrom = nil
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

    /// How long since the user last used the phone.
    func awayInterval(at date: Date = Date()) -> TimeInterval {
        guard let lastCheckIn else { return 0 }
        return max(0, date.timeIntervalSince(lastCheckIn))
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

    /// The longest stretch away from the phone today: either a finished gap
    /// between two pickups, or the one still running.
    var bestGapToday: TimeInterval {
        let timestamps = pickupTimestamps(on: Date())

        var best: TimeInterval = 0

        for (previous, next) in zip(timestamps, timestamps.dropFirst()) {
            best = max(best, next.timeIntervalSince(previous))
        }

        return max(best, awayInterval())
    }

    /// The longest stretch away, ever. Flattering, but true.
    var longestGapEver: TimeInterval {
        let all = events
            .filter { $0.kind == PhoneFreeEventKind.pickup }
            .map(\.timestamp)
            .sorted()

        var best: TimeInterval = 0

        for (previous, next) in zip(all, all.dropFirst()) {
            best = max(best, next.timeIntervalSince(previous))
        }

        return max(best, awayInterval())
    }

    /// The longest stretch away that is *finished*. Excludes the run happening
    /// right now, so "is this a new record?" has an honest answer.
    var bestCompletedGapEver: TimeInterval {
        let all = events
            .filter { $0.kind == PhoneFreeEventKind.pickup }
            .map(\.timestamp)
            .sorted()

        var best: TimeInterval = 0

        for (previous, next) in zip(all, all.dropFirst()) {
            best = max(best, next.timeIntervalSince(previous))
        }

        return best
    }

    /// `true` when the stretch happening right now has already beaten every
    /// finished one. Guarded on `> 0` so a fresh install does not instantly
    /// declare a record on its first second of use.
    var isNewLongestGap: Bool {
        bestCompletedGapEver > 0 && awayInterval() > bestCompletedGapEver
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

    // MARK: - The Lock Screen counter

    /// Makes the Lock Screen show what the app is about: how long since the
    /// phone was last used. With no goal running there is nothing to count
    /// down, so the counter counts up instead.
    ///
    /// Safe to call repeatedly — it refreshes an existing activity rather than
    /// stacking up new ones.
    func syncLockScreenCounter() {
        if goalActive,
           let start = goalStart,
           let end = goalEnd,
           end > Date() {
            PhoneFreeLiveActivityManager.shared.restoreIfNeeded(
                minutes: effectiveGoalMinutes,
                start: start,
                end: end,
                segments: buildSegments(from: start)
            )
            return
        }

        guard lockScreenCounterEnabled, let lastCheckIn else {
            PhoneFreeLiveActivityManager.shared.endCheckIn()
            return
        }

        PhoneFreeLiveActivityManager.shared.startCheckIn(since: lastCheckIn)
    }

    // MARK: - Data

    func clearAllData() {
        events = []
        reflections = []
        plan = []
        goalActive = false
        goalStart = nil
        goalEnd = nil
        lastCheckIn = Date()

        save()
        PhoneFreeLiveActivityManager.shared.end()
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
        lastCheckIn = Date()

        save()
        PhoneFreeLiveActivityManager.shared.end()
        syncLockScreenCounter()
    }

    // MARK: - Pickups

    private func pickupTimestamps(on date: Date) -> [Date] {
        events
            .filter {
                $0.kind == PhoneFreeEventKind.pickup &&
                Calendar.current.isDate($0.timestamp, inSameDayAs: date)
            }
            .map(\.timestamp)
            .sorted()
    }

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

        if defaults.object(forKey: "phoneFreeLockScreenCounter") != nil {
            lockScreenCounterEnabled = defaults.bool(
                forKey: "phoneFreeLockScreenCounter"
            )
        }

        if let timestamp = defaults.object(
            forKey: "phoneFreeLastCheckIn"
        ) as? Date {
            lastCheckIn = timestamp
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

        defaults.set(goalActive, forKey: "phoneFreeGoalActive")
        defaults.set(
            lockScreenCounterEnabled,
            forKey: "phoneFreeLockScreenCounter"
        )

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

        if let lastCheckIn {
            defaults.set(lastCheckIn, forKey: "phoneFreeLastCheckIn")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}

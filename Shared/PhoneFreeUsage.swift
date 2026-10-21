//
//  PhoneFreeUsage.swift
//  Shared
//
//  Compiled into BOTH the "Iphone app" target and the "PhoneFreeWidgetExtension"
//  target, so the app, the Shortcuts actions and the Lock Screen widget all
//  agree on what the away counter says.
//
//  "Since you last used your phone" counts the time the phone has been down.
//  The counter has two moments, not one:
//
//   * `lastCheckIn` — where the current stretch away counts from;
//   * `usingSince` — set while the phone is being used, `nil` otherwise.
//
//  While the phone is in use the screen shows a guard first: for the length of
//  the grace period the away counter holds the number it had earned, so a brief
//  pickup costs nothing and there is room to change your mind. After that the
//  counter turns red and counts the time in the hand, from zero. Put the phone
//  down inside the grace and the away counter carries on from where it was;
//  past it the stretch ends — it is recorded, and the counter starts again at
//  0:00 from the moment the phone goes down.
//
//  The guard is a *budget for the stretch*, not a fresh allowance on every
//  pickup. Using the phone spends it, and only a full guard-length away
//  recharges it. Without that, a quick lock and unlock would hand out another
//  whole minute and a long stretch could be kept forever by cycling in and
//  out of the phone.
//
//  Surplus is the reward layer on top of that. Finishing a phone-free goal
//  banks free phone time; while it lasts it pays for use *past* the grace
//  period, so the counter stays frozen instead of resetting. Spend it all and
//  the ordinary rule resumes. The bank is capped, so it can never quietly
//  become "unlimited phone".
//
//  iOS gives no unlock or "stopped using" signal, so `usingSince` is only as
//  good as what reports it: PhoneFree being open, and the Shortcuts
//  automations the user sets up for the apps that pull at them. A session
//  nobody closes is treated as abandoned after `abandonAfter`, so a missed
//  "closed" signal cannot freeze the counter forever.
//

import Foundation

nonisolated enum PhoneFreeUsage {

    static let appGroupID = "group.com.danielebuatti.phonefree"

    static let lastCheckInKey = "phoneFreeLastCheckIn"
    static let usingSinceKey = "phoneFreeUsingSince"
    static let resetAfterKey = "phoneFreeResetAfter"
    static let bestEverKey = "phoneFreeBestStretch"
    static let bestTodayKey = "phoneFreeBestStretchToday"
    static let bestTodayDayKey = "phoneFreeBestStretchDay"
    static let stretchEndingsKey = "phoneFreeStretchEndings"
    static let stretchRecordedKey = "phoneFreeStretchRecorded"
    static let surplusKey = "phoneFreeSurplus"
    static let guardUsedKey = "phoneFreeGuardUsed"
    static let lastUseEndKey = "phoneFreeLastUseEnd"

    /// The most free time the bank will hold. An hour is enough to matter and
    /// small enough that it cannot quietly become "unlimited phone".
    static let maxSurplus: TimeInterval = 60 * 60

    /// Seconds of use before the counter turns red. This is a budget for the
    /// whole stretch, spent by use and recharged by being away for at least
    /// this long — not a fresh allowance every time the phone is picked up.
    static let defaultResetAfter: TimeInterval = 60

    /// The grace periods offered in Settings.
    static let resetAfterOptions: [TimeInterval] = [30, 60, 120]

    /// How often the "your streak resets in…" reminder repeats.
    static let reminderInterval: TimeInterval = 15

    /// A use session with no "put down" signal is assumed over after this.
    static let abandonAfter: TimeInterval = 30 * 60

    // MARK: - State

    struct State: Equatable {
        var lastCheckIn: Date?
        var usingSince: Date?
        var resetAfter: TimeInterval = PhoneFreeUsage.defaultResetAfter

        /// Banked free phone time, earned by finishing phone-free goals. While
        /// the phone is in use it is spent at one second per second, after the
        /// base grace period, so the counter keeps its freeze instead of
        /// resetting to zero. Doing activities buys freedom to use the phone
        /// without losing the number.
        var surplus: TimeInterval = 0

        /// Guard seconds already spent in the current stretch. The guard is a
        /// budget for the whole stretch: use spends it, and a full guard-length
        /// away recharges it. A quick lock and unlock keeps only what is left,
        /// so it cannot be farmed into another whole minute. `nil` means
        /// nothing has been spent yet (fresh install, or an older saved state).
        var guardUsed: TimeInterval?

        /// The last moment the phone was put down. The guard recharges only
        /// after the user has been away for the full guard length.
        var lastUseEnd: Date?

        /// The longest *finished* stretch ever, and today's. A stretch
        /// finishes when the counter goes back to zero — not when the phone is
        /// briefly picked up — so one stretch is recorded once, at its end.
        ///
        /// Stored as *awake* time: planned phone-free windows (sleep above
        /// all) are taken out when the stretch is recorded, so a night of
        /// nobody-touching-the-phone never reads as an achievement. The live
        /// counter stays raw — away really is away.
        var bestEver: TimeInterval = 0
        var bestToday: TimeInterval = 0
        var bestTodayDay: Date?

        /// The phone-free windows in force — read back from the same defaults
        /// the app saves them to, never written by this type. Only the app's
        /// store edits them; every surface (app, widget) reads the same copy,
        /// so they all exclude the same stretches.
        var sleepWindows: [PhoneFreeWindow] = []

        /// How many stretches have ended because the phone went back in hand
        /// past its grace — counted by exactly the two transitions that mean
        /// that (a use that ran the counter out, an abandoned session
        /// settled), and by nothing else: a goal starting, a lock, a wipe are
        /// not pickups. Shared sessions watch it to learn that the room needs
        /// to be told. Persisted so a relaunch does not replay old trips.
        var stretchEndings: Int = 0

        /// True once the grace period (and any banked surplus) has run out on
        /// this open session: the stretch has been recorded and the counter is
        /// frozen at it. Stays true until the phone goes down, so the
        /// countdown and the reminders do not re-arm themselves after the
        /// reset.
        var stretchRecorded: Bool = false

        /// Today's best finished stretch, or zero on a new day.
        func bestFinishedToday(at now: Date) -> TimeInterval {
            guard let bestTodayDay,
                  Calendar.current.isDate(bestTodayDay, inSameDayAs: now)
            else { return 0 }
            return bestToday
        }

        /// The guard still available for the open session, in seconds. It is
        /// the configured guard minus what this stretch has already spent.
        var guardSeconds: TimeInterval {
            max(0, resetAfter - min(guardUsed ?? 0, resetAfter))
        }

        /// The moment the base grace period ends and surplus starts paying.
        var baseGraceEndsAt: Date? {
            guardEndsAt
        }

        /// The moment the base grace ends: the phone can be picked up for this
        /// long, with the away counter holding its number, before the time
        /// starts counting against the user in red. Banked free time extends
        /// how long the *stretch* survives (see `resetsAt`), not this window.
        var guardEndsAt: Date? {
            usingSince?.addingTimeInterval(guardSeconds)
        }

        /// The moment the shield ends: the available guard plus whatever
        /// surplus is banked. Put the phone down before it and the stretch
        /// carries on; stay on it until it and the stretch is over, with the
        /// counter starting again at 0:00 on the put-down.
        var resetsAt: Date? {
            usingSince?.addingTimeInterval(guardSeconds + surplus)
        }

        /// How much of this session's use surplus is absorbing — the seconds
        /// used past the available guard, capped at the bank.
        func surplusInUse(at now: Date) -> TimeInterval {
            guard let usingSince else { return 0 }
            let used = max(0, now.timeIntervalSince(usingSince))
            return min(surplus, max(0, used - guardSeconds))
        }

        /// Surplus left once this session's use is paid for.
        func surplusRemaining(at now: Date) -> TimeInterval {
            max(0, surplus - surplusInUse(at: now))
        }

        /// `true` when a session is being shielded by surplus — worth saying
        /// out loud, because it is the reward for the activities just done.
        func isShielded(at now: Date) -> Bool {
            isUsing(at: now) && surplusInUse(at: now) > 0
        }

        /// A session is abandoned only when it is past the shield *and* the
        /// long stop-gap, so surplus-covered use is never mistaken for an
        /// abandoned one.
        func isAbandoned(at now: Date) -> Bool {
            guard let usingSince else { return false }
            let used = now.timeIntervalSince(usingSince)
            return used >= guardSeconds + surplus
                && used >= PhoneFreeUsage.abandonAfter
        }

        /// `true` while the phone is being used and the session is live.
        func isUsing(at now: Date) -> Bool {
            usingSince != nil && !isAbandoned(at: now)
        }

        /// `true` once the grace period *and* the surplus have run out on the
        /// open session — the point the stretch is forfeit. The counter itself
        /// starts again at 0:00 when the phone is put down.
        func hasReset(at now: Date) -> Bool {
            guard isUsing(at: now), let resetsAt else { return false }
            return stretchRecorded || now >= resetsAt
        }

        /// The stretch the current session froze — what the user stands to
        /// lose if they keep going.
        var frozenInterval: TimeInterval {
            guard let lastCheckIn, let usingSince else { return 0 }
            return max(0, usingSince.timeIntervalSince(lastCheckIn))
        }

        /// `true` when the open session puts something worth keeping at risk.
        /// Below a minute there is nothing to lose, so the app stays quiet
        /// rather than counting down over a zero.
        var hasStretchAtStake: Bool {
            usingSince != nil && frozenInterval >= 60 && !stretchRecorded
        }

        /// The raw away value the state machine records. While the phone is
        /// in use this is negative hand-time; the screen does not show it
        /// directly, because the first available guard seconds are a hold (see
        /// `displayInterval`). Put it down inside the grace and the away
        /// counter carries on from the earned stretch; past the grace the
        /// stretch is recorded and the counter starts again at zero.
        func awayInterval(at now: Date) -> TimeInterval {
            if isUsing(at: now), let usingSince {
                return -max(0, now.timeIntervalSince(usingSince))
            }

            let settled = settled(at: now)
            guard let since = settled.lastCheckIn else { return 0 }
            return max(0, now.timeIntervalSince(since))
        }

        /// What the counter shows, as opposed to what the machine records.
        ///
        /// The first available guard seconds of a pickup are a hold: the away
        /// timer holds at the stretch it had earned, so a brief pickup costs
        /// nothing and there is room to change your mind. Only once that
        /// window runs out does the number turn negative in red, and it starts
        /// from zero at the end of the guard — the guard itself is not charged
        /// as phone-in-hand time. Put the phone down and the away counter
        /// either carries on (inside the grace) or restarts (past it).
        func displayInterval(at now: Date) -> TimeInterval {
            guard isUsing(at: now), let usingSince else {
                return awayInterval(at: now)
            }

            let guardEnd = usingSince.addingTimeInterval(guardSeconds)
            guard now >= guardEnd else { return frozenInterval }

            return -max(0, now.timeIntervalSince(guardEnd))
        }

        /// `true` once the guard has run out and the counter is showing the
        /// time in hand in red.
        func isPastGuard(at now: Date) -> Bool {
            guard isUsing(at: now), let guardEndsAt else { return false }
            return now >= guardEndsAt
        }

        /// The live stretch with sleep excluded, for milestones and progress.
        ///
        /// While the phone is in use it holds at the sleep-adjusted frozen
        /// stretch, so the bar does not drop to zero while the number holds.
        /// It keeps holding past the guard if banked free time is still
        /// protecting the run, and reads zero once the run is forfeit — the
        /// red hand-time number and the stretch's fate are separate things.
        func awakeDisplayInterval(at now: Date) -> TimeInterval {
            guard isUsing(at: now), let usingSince else {
                return awakeAwayInterval(at: now)
            }

            guard !hasReset(at: now) else { return 0 }

            let shown = frozenInterval
            let anchor = usingSince.addingTimeInterval(-shown)
            let inWindows = PhoneFreeWindow.overlap(
                from: anchor,
                to: anchor.addingTimeInterval(shown),
                in: sleepWindows
            )

            return max(0, shown - inWindows)
        }

        /// The date the counter counts up from when it is running, or `nil`
        /// while it is frozen or held at zero.
        func countingSince(at now: Date) -> Date? {
            guard !isUsing(at: now) else { return usingSince }
            return settled(at: now).lastCheckIn
        }

        /// The stretch the number on screen belongs to: where it started, or
        /// `nil` when there is nothing to count from. Frozen stretches count
        /// from their own start too, so an in-hand number still maps to real
        /// wall-clock time.
        func awayAnchor(at now: Date) -> Date? {
            if isUsing(at: now) {
                return usingSince.map {
                    $0.addingTimeInterval(-frozenInterval)
                }
            }
            return countingSince(at: now)
        }

        /// What the counter would read if sleep didn't count — the stretch
        /// minus its overlap with the phone-free windows. Stats and milestone
        /// rungs read this; the counter itself stays raw, because away really
        /// is away. With no windows set, the two are the same number.
        func awakeAwayInterval(at now: Date) -> TimeInterval {
            let earned = awayInterval(at: now)
            guard earned > 0,
                  !sleepWindows.isEmpty,
                  let anchor = awayAnchor(at: now)
            else { return max(0, earned) }

            let inWindows = PhoneFreeWindow.overlap(
                from: anchor,
                to: anchor.addingTimeInterval(earned),
                in: sleepWindows
            )

            return max(0, earned - inWindows)
        }

        // MARK: Transitions

        /// The phone has been picked up. An open session is kept, so moving
        /// from one app to another does not restart the grace period.
        mutating func beginUse(at now: Date) {
            self = settled(at: now)
            if usingSince == nil {
                // The guard is a per-stretch budget. Only a genuine away
                // period — the full guard length — recharges it; a quick lock
                // and unlock keeps whatever was left, rather than handing out
                // a fresh minute. With no put-down on record (first run, or an
                // older state) the guard starts full.
                if let lastUseEnd,
                   now.timeIntervalSince(lastUseEnd) >= resetAfter {
                    guardUsed = 0
                }

                usingSince = now
                stretchRecorded = false
            }
        }

        /// The phone has been put down. Inside the grace (and any banked free
        /// time) the stretch survives: the in-hand seconds are taken off the
        /// clock, so the away counter resumes at the number it read when the
        /// phone was picked up. Past the shield the stretch ends: it is
        /// recorded, and the away counter starts again at 0:00 from this
        /// put-down. Only the latter counts as a stretch lost to use (which is
        /// what shared sessions watch).
        mutating func endUse(at now: Date) {
            guard let usingSince, !isAbandoned(at: now) else {
                self = settled(at: now)
                return
            }

            let used = max(0, now.timeIntervalSince(usingSince))
            let available = guardSeconds

            // Still inside the shield: the stretch carries on. Shift the away
            // anchor forward by the time the phone was in the hand, so the
            // counter resumes at exactly the value it was paused on. Use past
            // the available guard is paid for out of the bank at one second
            // each.
            if !stretchRecorded, used < available + surplus {
                // Spend the guard this stretch already had. Once spent, only
                // a full guard-length away brings it back.
                guardUsed = min(resetAfter, (guardUsed ?? 0) + used)
                surplus = max(0, surplus - max(0, used - available))

                if let lastCheckIn {
                    self.lastCheckIn = lastCheckIn.addingTimeInterval(used)
                } else {
                    self.lastCheckIn = now
                }

                self.usingSince = nil
                lastUseEnd = now
                return
            }

            // Past the whole shield: the stretch is over. Record it once — a
            // stretch already recorded while the phone stayed in hand (see
            // `keepAlive`) must not be recorded a second time — and start the
            // counter again from this put-down.
            if !stretchRecorded {
                let earned = frozenInterval
                if earned > 0 {
                    record(earned, endedAt: usingSince)
                }
            }

            surplus = 0
            stretchEndings += 1
            self.lastCheckIn = now
            self.usingSince = nil
            stretchRecorded = false
            // The stretch is spent too: no fresh guard until the user has
            // genuinely been away again.
            guardUsed = resetAfter
            lastUseEnd = now
        }

        /// The counter starts again from zero right now (a goal starting, a
        /// promise broken, a clean slate).
        mutating func restart(at now: Date) {
            if isUsing(at: now), let usingSince {
                record(frozenInterval, endedAt: usingSince)
            } else {
                record(awayInterval(at: now), endedAt: now)
            }

            lastCheckIn = now
            usingSince = nil
            stretchRecorded = false
            guardUsed = nil
            lastUseEnd = now
        }

        /// The counter starts again from zero right now, recording nothing on
        /// the way out. Forgetting the data must not *write* new data — the
        /// stretch being erased is exactly the kind that would otherwise set
        /// (and keep) a record.
        mutating func forget(at now: Date) {
            lastCheckIn = now
            usingSince = nil
            bestToday = 0
            bestTodayDay = nil
            stretchRecorded = false
            guardUsed = nil
            lastUseEnd = now
        }

        /// Back to a fresh install, with no record of anything — used by
        /// "Clear all data". `restart` would leave the all-time record behind;
        /// this takes it too, because a wiped history cannot vouch for it.
        mutating func wipe() {
            self = State()
            lastCheckIn = Date()
        }

        /// Called every so often while PhoneFree itself is open — a use signal
        /// that is certain, so the session must never be given up on as
        /// abandoned. Past the grace, the visit charges the surplus and the
        /// session is re-anchored to now, so the shield stays honest.
        mutating func keepAlive(at now: Date) {
            guard let usingSince else {
                beginUse(at: now)
                return
            }

            guard now.timeIntervalSince(usingSince) > 10 * 60 else { return }

            let used = now.timeIntervalSince(usingSince)
            let available = guardSeconds

            if used < available + surplus, let lastCheckIn {
                // Free time paid for the visit; keep the streak and the shield.
                // The visit spends the guard budget for the stretch too.
                guardUsed = min(resetAfter, (guardUsed ?? 0) + used)
                self.lastCheckIn = lastCheckIn.addingTimeInterval(used)
                surplus = max(0, surplus - max(0, used - available))
            } else {
                // The whole shield is spent, so the run is over and recorded
                // now — but the number it earned is kept on screen. The
                // counter is never blanked to 0:00 while the phone is still in
                // the user's hand; it restarts when the phone goes down.
                let frozen = frozenInterval
                record(frozen, endedAt: usingSince)
                lastCheckIn = now.addingTimeInterval(-frozen)
                surplus = 0
                stretchRecorded = true
                guardUsed = resetAfter
            }

            self.usingSince = now
        }

        /// Credits earned phone-free time to the bank, capped. Returns how much
        /// was actually banked, so the UI can honestly say "+20 min" only when
        /// all of it landed.
        @discardableResult
        mutating func creditSurplus(_ seconds: TimeInterval) -> TimeInterval {
            guard seconds >= 1 else { return 0 }
            let room = max(0, PhoneFreeUsage.maxSurplus - surplus)
            let credited = min(seconds, room)
            surplus += credited
            return credited
        }

        /// An abandoned session folded into `lastCheckIn`: it is assumed to
        /// have run past the whole shield, so the reset stands from then and
        /// the bank is spent.
        func settled(at now: Date) -> State {
            guard isAbandoned(at: now), let resetsAt else { return self }

            var copy = self
            copy.record(frozenInterval, endedAt: resetsAt)
            copy.lastCheckIn = resetsAt
            copy.usingSince = nil
            copy.surplus = 0
            // Abandoned means the phone was in hand past every grace — this
            // settle is a stretch lost to use, so it counts as a pickup the
            // same way `endUse` running out does.
            copy.stretchEndings += 1
            copy.stretchRecorded = false
            // An abandoned session has spent the stretch's guard too.
            copy.guardUsed = resetAfter
            copy.lastUseEnd = now
            return copy
        }

        private mutating func record(_ stretch: TimeInterval, endedAt: Date) {
            // Only awake time counts: window overlap — sleep above all — comes
            // out before the stretch is considered, so an overnight phone left
            // alone never sets a record nobody chose.
            let awake = max(
                0,
                stretch - PhoneFreeWindow.overlap(
                    from: endedAt.addingTimeInterval(-stretch),
                    to: endedAt,
                    in: sleepWindows
                )
            )

            bestEver = max(bestEver, awake)

            if let bestTodayDay,
               Calendar.current.isDate(bestTodayDay, inSameDayAs: endedAt) {
                bestToday = max(bestToday, awake)
            } else {
                bestToday = awake
                bestTodayDay = endedAt
            }
        }
    }

    // MARK: - Shared storage

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func load() -> State {
        let defaults = defaults

        let resetAfter = defaults?.double(forKey: resetAfterKey) ?? 0

        // The windows are owned (and persisted) by the app's store; read here
        // so this type alone is enough for every surface to exclude the same
        // stretches. Nothing in this file ever writes them back.
        let sleepWindows = (try? JSONDecoder().decode(
            [PhoneFreeWindow].self,
            from: defaults?.data(forKey: PhoneFreeWindow.defaultsKey) ?? Data()
        )) ?? []

        return State(
            lastCheckIn: defaults?.object(forKey: lastCheckInKey) as? Date,
            usingSince: defaults?.object(forKey: usingSinceKey) as? Date,
            resetAfter: resetAfter > 0 ? resetAfter : defaultResetAfter,
            surplus: defaults?.double(forKey: surplusKey) ?? 0,
            guardUsed: defaults?.object(forKey: guardUsedKey) != nil
                ? defaults?.double(forKey: guardUsedKey)
                : nil,
            lastUseEnd: defaults?.object(forKey: lastUseEndKey) as? Date,
            bestEver: defaults?.double(forKey: bestEverKey) ?? 0,
            bestToday: defaults?.double(forKey: bestTodayKey) ?? 0,
            bestTodayDay: defaults?.object(forKey: bestTodayDayKey) as? Date,
            sleepWindows: sleepWindows,
            stretchEndings: defaults?.integer(forKey: stretchEndingsKey) ?? 0,
            stretchRecorded: defaults?.bool(forKey: stretchRecordedKey) ?? false
        )
    }

    static func save(_ state: State) {
        guard let defaults else { return }

        if let lastCheckIn = state.lastCheckIn {
            defaults.set(lastCheckIn, forKey: lastCheckInKey)
        }

        if let usingSince = state.usingSince {
            defaults.set(usingSince, forKey: usingSinceKey)
        } else {
            defaults.removeObject(forKey: usingSinceKey)
        }

        defaults.set(state.resetAfter, forKey: resetAfterKey)
        defaults.set(state.surplus, forKey: surplusKey)
        defaults.set(state.bestEver, forKey: bestEverKey)
        defaults.set(state.bestToday, forKey: bestTodayKey)

        if let day = state.bestTodayDay {
            defaults.set(day, forKey: bestTodayDayKey)
        } else {
            defaults.removeObject(forKey: bestTodayDayKey)
        }

        defaults.set(state.stretchEndings, forKey: stretchEndingsKey)
        defaults.set(state.stretchRecorded, forKey: stretchRecordedKey)

        if let guardUsed = state.guardUsed {
            defaults.set(guardUsed, forKey: guardUsedKey)
        } else {
            defaults.removeObject(forKey: guardUsedKey)
        }

        if let lastUseEnd = state.lastUseEnd {
            defaults.set(lastUseEnd, forKey: lastUseEndKey)
        } else {
            defaults.removeObject(forKey: lastUseEndKey)
        }
    }

    /// "30 seconds", "1 minute", "2 minutes" — for sentences, where "1m"
    /// would read as a code.
    static func words(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))

        if seconds % 60 == 0, seconds >= 60 {
            let minutes = seconds / 60
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }

        return seconds == 1 ? "1 second" : "\(seconds) seconds"
    }

    /// Short "45s", "1m", "2m" for reminders and captions.
    static func shortSeconds(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        if seconds < 60 || seconds % 60 != 0 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m"
    }
}

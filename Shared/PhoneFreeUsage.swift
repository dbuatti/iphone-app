//
//  PhoneFreeUsage.swift
//  Shared
//
//  Compiled into BOTH the "Iphone app" target and the "PhoneFreeWidgetExtension"
//  target, so the app, the Shortcuts actions and the Lock Screen widget all
//  agree on what the away counter says.
//
//  "Since you last used your phone" should not tick up while the phone is in
//  your hand. So the counter has two moments, not one:
//
//   * `lastCheckIn` — where the current stretch away counts from;
//   * `usingSince` — set while the phone is being used, `nil` otherwise.
//
//  While the phone is in use the counter is frozen. Put it down within the
//  grace period (60 seconds by default) and the stretch carries on as if those
//  seconds never happened. Still on it after the grace period, and the counter
//  goes to zero and stays there until the phone is put down.
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
    static let surplusKey = "phoneFreeSurplus"

    /// The most free time the bank will hold. An hour is enough to matter and
    /// small enough that it cannot quietly become "unlimited phone".
    static let maxSurplus: TimeInterval = 60 * 60

    /// Seconds of use before the counter resets. Long enough to check the
    /// time or answer one message; short enough that scrolling never fits.
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

        /// The longest *finished* stretch ever, and today's. A stretch
        /// finishes when the counter goes back to zero — not when the phone is
        /// briefly picked up — so these always agree with the counter.
        var bestEver: TimeInterval = 0
        var bestToday: TimeInterval = 0
        var bestTodayDay: Date?

        /// Today's best finished stretch, or zero on a new day.
        func bestFinishedToday(at now: Date) -> TimeInterval {
            guard let bestTodayDay,
                  Calendar.current.isDate(bestTodayDay, inSameDayAs: now)
            else { return 0 }
            return bestToday
        }

        /// The moment the base grace period ends and surplus starts paying.
        var baseGraceEndsAt: Date? {
            usingSince?.addingTimeInterval(resetAfter)
        }

        /// The moment the counter resets: the base grace plus whatever surplus
        /// is banked. While a session is open, this is the end of the shield.
        var resetsAt: Date? {
            usingSince?.addingTimeInterval(resetAfter + surplus)
        }

        /// How much of this session's use surplus is absorbing — the seconds
        /// used past the base grace, capped at the bank.
        func surplusInUse(at now: Date) -> TimeInterval {
            guard let usingSince else { return 0 }
            let used = max(0, now.timeIntervalSince(usingSince))
            return min(surplus, max(0, used - resetAfter))
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
            return used >= resetAfter + surplus
                && used >= PhoneFreeUsage.abandonAfter
        }

        /// `true` while the phone is being used and the session is live.
        func isUsing(at now: Date) -> Bool {
            usingSince != nil && !isAbandoned(at: now)
        }

        /// `true` once the grace period *and* the surplus have run out on the
        /// open session — the point the streak actually resets.
        func hasReset(at now: Date) -> Bool {
            guard isUsing(at: now), let resetsAt else { return false }
            return now >= resetsAt
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
            usingSince != nil && frozenInterval >= 60
        }

        /// The number on screen.
        func awayInterval(at now: Date) -> TimeInterval {
            if isUsing(at: now) {
                return hasReset(at: now) ? 0 : frozenInterval
            }

            let settled = settled(at: now)
            guard let since = settled.lastCheckIn else { return 0 }
            return max(0, now.timeIntervalSince(since))
        }

        /// The date the counter counts up from when it is running, or `nil`
        /// while it is frozen or held at zero.
        func countingSince(at now: Date) -> Date? {
            guard !isUsing(at: now) else { return nil }
            return settled(at: now).lastCheckIn
        }

        // MARK: Transitions

        /// The phone has been picked up. An open session is kept, so moving
        /// from one app to another does not restart the grace period.
        mutating func beginUse(at now: Date) {
            self = settled(at: now)
            if usingSince == nil {
                usingSince = now
            }
        }

        /// The phone has been put down. Inside the base grace the used seconds
        /// are skipped, not counted. Past it, surplus pays for them and the
        /// streak survives. Only when both run out does the counter reset.
        mutating func endUse(at now: Date) {
            guard let usingSince, !isAbandoned(at: now) else {
                self = settled(at: now)
                return
            }

            let used = max(0, now.timeIntervalSince(usingSince))

            if used < resetAfter + surplus, let lastCheckIn {
                // The phone time was free — the counter skips it entirely.
                self.lastCheckIn = lastCheckIn.addingTimeInterval(used)
                surplus = max(0, surplus - max(0, used - resetAfter))
            } else {
                record(frozenInterval, endedAt: usingSince)
                self.lastCheckIn = now
                surplus = 0
            }

            self.usingSince = nil
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

            if used < resetAfter + surplus, let lastCheckIn {
                // Free time paid for the visit; keep the streak and the shield.
                self.lastCheckIn = lastCheckIn.addingTimeInterval(used)
                surplus = max(0, surplus - max(0, used - resetAfter))
            } else {
                record(frozenInterval, endedAt: usingSince)
                lastCheckIn = now
                surplus = 0
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
            return copy
        }

        private mutating func record(_ stretch: TimeInterval, endedAt: Date) {
            bestEver = max(bestEver, stretch)

            if let bestTodayDay,
               Calendar.current.isDate(bestTodayDay, inSameDayAs: endedAt) {
                bestToday = max(bestToday, stretch)
            } else {
                bestToday = stretch
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

        return State(
            lastCheckIn: defaults?.object(forKey: lastCheckInKey) as? Date,
            usingSince: defaults?.object(forKey: usingSinceKey) as? Date,
            resetAfter: resetAfter > 0 ? resetAfter : defaultResetAfter,
            surplus: defaults?.double(forKey: surplusKey) ?? 0,
            bestEver: defaults?.double(forKey: bestEverKey) ?? 0,
            bestToday: defaults?.double(forKey: bestTodayKey) ?? 0,
            bestTodayDay: defaults?.object(forKey: bestTodayDayKey) as? Date
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

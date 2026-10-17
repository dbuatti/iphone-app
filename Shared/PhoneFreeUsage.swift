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

        /// The moment the counter resets, while a use session is open.
        var resetsAt: Date? {
            usingSince?.addingTimeInterval(resetAfter)
        }

        func isAbandoned(at now: Date) -> Bool {
            guard let usingSince else { return false }
            return now.timeIntervalSince(usingSince) >= PhoneFreeUsage.abandonAfter
        }

        /// `true` while the phone is being used and the session is live.
        func isUsing(at now: Date) -> Bool {
            usingSince != nil && !isAbandoned(at: now)
        }

        /// `true` once the grace period has run out on the open session.
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

        /// The phone has been put down. Inside the grace period the used
        /// seconds are skipped, not counted; past it, the stretch starts again
        /// from now.
        mutating func endUse(at now: Date) {
            guard let usingSince, !isAbandoned(at: now) else {
                self = settled(at: now)
                return
            }

            let used = max(0, now.timeIntervalSince(usingSince))

            if used < resetAfter, let lastCheckIn {
                self.lastCheckIn = lastCheckIn.addingTimeInterval(used)
            } else {
                self.lastCheckIn = now
            }

            self.usingSince = nil
        }

        /// The counter starts again from zero right now (a goal starting, a
        /// promise broken, a clean slate).
        mutating func restart(at now: Date) {
            lastCheckIn = now
            usingSince = nil
        }

        /// An abandoned session folded into `lastCheckIn`: it is assumed to
        /// have run past the grace period, so the reset stands from then.
        func settled(at now: Date) -> State {
            guard isAbandoned(at: now), let resetsAt else { return self }

            var copy = self
            copy.lastCheckIn = resetsAt
            copy.usingSince = nil
            return copy
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
            resetAfter: resetAfter > 0 ? resetAfter : defaultResetAfter
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

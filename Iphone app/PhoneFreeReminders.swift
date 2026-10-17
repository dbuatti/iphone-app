//
//  PhoneFreeReminders.swift
//  Iphone app
//
//  The two kinds of nudge that can reach the user while PhoneFree is closed.
//
//   * Use reminders — every 15 seconds after a distracting app opens: "your
//     streak resets in 45s". They appear as banners over whatever app is open,
//     which is the only way an app without the Screen Time entitlement can
//     interrupt another one. A button on each lets the user put the phone down
//     without opening anything.
//
//   * Goal nudges — every few minutes while a goal runs, so the first thing on
//     the Lock Screen when the phone is woken is the goal they promised.
//
//  Both are quiet (no sound) and grouped into their own thread, so they read
//  as a single conversation rather than a pile.
//

import Foundation
import UserNotifications
import WidgetKit

// MARK: - Use reminders

enum PhoneFreeUseReminders {
    static let categoryID = "PHONEFREE_USE"
    static let putDownActionID = "PUT_DOWN"
    static let requestPrefix = "pf_use_"

    static var category: UNNotificationCategory {
        UNNotificationCategory(
            identifier: categoryID,
            actions: [
                UNNotificationAction(
                    identifier: putDownActionID,
                    title: "I've put it down",
                    options: []
                ),
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    /// One nudge every 15 seconds through the base grace, then a few spaced
    /// ones if banked free time is paying for the session, then one that says
    /// the reset happened.
    ///
    /// Delays are measured from *this* moment, not from when the session
    /// began. PhoneFree is often open for a while before the user moves to
    /// another app, and a reminder anchored to the session's start would
    /// already be in the past and never arrive.
    static func schedule(for state: PhoneFreeUsage.State, now: Date = Date()) {
        guard let usingSince = state.usingSince else { return }

        cancel()

        guard let resetsAt = state.resetsAt else { return }

        let center = UNUserNotificationCenter.current()
        let streak = PhoneFreeFormat.clock(state.frozenInterval)
        let hasStreak = state.frozenInterval >= 60
        let baseEnd = usingSince.addingTimeInterval(state.resetAfter)

        var index = 0

        func add(delay: TimeInterval, title: String, body: String) {
            guard delay > 0, index < maxReminders else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.categoryIdentifier = categoryID
            content.threadIdentifier = "pf_use"
            content.interruptionLevel = .active

            center.add(
                UNNotificationRequest(
                    identifier: requestPrefix + "\(index)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(
                        timeInterval: delay,
                        repeats: false
                    )
                )
            )

            index += 1
        }

        // Already past the whole shield: the streak is gone, so there is no
        // countdown left to run — just one nudge to put the phone down.
        guard resetsAt > now else {
            add(
                delay: PhoneFreeUsage.reminderInterval,
                title: "Your timer started again",
                body: "That's okay. Put your phone down and it counts up "
                    + "from there."
            )
            return
        }

        // Urgent: the base grace, every 15 seconds. This is the countdown
        // that is most likely to be seen.
        var fireAt = now.addingTimeInterval(PhoneFreeUsage.reminderInterval)

        // With free time banked the streak is not actually at risk through the
        // grace — the bank pays for it — so the same nudge has to say something
        // different, or it would be telling a small lie.
        let banked = state.surplus > 0

        while fireAt < min(resetsAt, baseEnd), index < maxReminders - 1 {
            let remaining = resetsAt.timeIntervalSince(fireAt)

            // A question and one concrete thing to do — never a judgement.
            // Shame is what keeps people scrolling.
            add(
                delay: fireAt.timeIntervalSince(now),
                title: "Do you still want to be on your phone?",
                body: banked
                    ? "Your streak is safe — "
                        + "\(PhoneFreeUsage.shortSeconds(remaining)) of banked "
                        + "free time left. Put your phone down to keep what's "
                        + "left."
                    : (hasStreak
                        ? "Your \(streak) resets in "
                        : "Your timer resets in ")
                        + "\(PhoneFreeUsage.shortSeconds(remaining)). "
                        + "Lock your phone to keep it."
            )

            fireAt = fireAt.addingTimeInterval(PhoneFreeUsage.reminderInterval)
        }

        // Shielded: earned free time is paying for the session. Spaced out,
        // so a banked hour never turns into an hour of notifications.
        if resetsAt > baseEnd {
            var shieldAt = max(baseEnd, now)
                .addingTimeInterval(shieldInterval)

            while shieldAt < resetsAt, index < maxReminders - 1 {
                let left = resetsAt.timeIntervalSince(shieldAt)

                add(
                    delay: shieldAt.timeIntervalSince(now),
                    title: "Free time protecting your streak",
                    body: "\(PhoneFreeUsage.shortSeconds(left)) of banked free "
                        + "time left. Put your phone down to keep "
                        + "what's left."
                )

                shieldAt = shieldAt.addingTimeInterval(shieldInterval)
            }
        }

        // The reset itself, right on the second.
        add(
            delay: resetsAt.timeIntervalSince(now),
            title: "Your timer started again",
            body: "That's okay. It counts up again from the moment you put "
                + "your phone down."
        )
    }

    /// Enough to cover the grace and a shielded session without ever crowding
    /// iOS's 64 pending-notification limit.
    private static let maxReminders = 14

    /// How far apart the "free time is paying" reminders sit.
    private static let shieldInterval: TimeInterval = 5 * 60

    static func cancel() {
        let ids = (0...20).map { requestPrefix + "\($0)" }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// "I've put it down" from a reminder, without opening the app.
    static func putDown(at now: Date = Date()) {
        var state = PhoneFreeUsage.load()
        state.endUse(at: now)
        PhoneFreeUsage.save(state)

        cancel()
        WidgetCenter.shared.reloadAllTimelines()

        NotificationCenter.default.post(name: .phoneFreeUsageChanged, object: nil)

        Task {
            await PhoneFreeLiveActivityManager.shared.showAwayCounter(state)
        }
    }
}

extension Notification.Name {
    /// Posted when something outside the store (a Shortcuts action, a
    /// notification button) changed the shared counter.
    static let phoneFreeUsageChanged = Notification.Name("phonefreeUsageChanged")
}

// MARK: - Goal nudges

enum PhoneFreeGoalNudges {
    static let requestPrefix = "pf_goal_"

    /// iOS keeps at most 64 pending notifications per app; the windows use a
    /// few, so the nudges stay well under that.
    private static let maxNudges = 40
    private static let preferredInterval: TimeInterval = 5 * 60

    static func schedule(start: Date, end: Date, now: Date = Date()) {
        cancel()

        let total = end.timeIntervalSince(start)
        guard total > preferredInterval else { return }

        // Long goals (an overnight window) space the nudges out rather than
        // running out of them.
        let interval = max(
            preferredInterval,
            (total / Double(maxNudges) / 60).rounded(.up) * 60
        )

        let center = UNUserNotificationCenter.current()
        var fireAt = start.addingTimeInterval(interval)
        var index = 0

        while fireAt < end, index < maxNudges {
            let delay = fireAt.timeIntervalSince(now)

            if delay > 0 {
                let left = end.timeIntervalSince(fireAt)
                let content = UNMutableNotificationContent()

                content.title = "Phone-free goal running"
                content.body = "\(PhoneFreeFormat.duration(left)) to go. "
                    + "Put it back down — you're doing it."
                content.threadIdentifier = "pf_goal"
                content.interruptionLevel = .active

                center.add(
                    UNNotificationRequest(
                        identifier: requestPrefix + "\(index)",
                        content: content,
                        trigger: UNTimeIntervalNotificationTrigger(
                            timeInterval: delay,
                            repeats: false
                        )
                    )
                )
            }

            fireAt = fireAt.addingTimeInterval(interval)
            index += 1
        }
    }

    static func cancel() {
        let ids = (0..<maxNudges).map { requestPrefix + "\($0)" }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}

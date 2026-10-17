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

    /// One reminder every 15 seconds through the grace period, then one that
    /// says the reset happened. Timed from when the session began, so a late
    /// call never stretches the grace period.
    static func schedule(for state: PhoneFreeUsage.State, now: Date = Date()) {
        guard let usingSince = state.usingSince else { return }

        cancel()

        let center = UNUserNotificationCenter.current()
        let streak = PhoneFreeFormat.clock(state.frozenInterval)
        let hasStreak = state.frozenInterval >= 60

        var offset = PhoneFreeUsage.reminderInterval
        var index = 0

        while offset <= state.resetAfter {
            let fireAt = usingSince.addingTimeInterval(offset)
            let delay = fireAt.timeIntervalSince(now)

            if delay > 0 {
                let remaining = state.resetAfter - offset
                let content = UNMutableNotificationContent()

                if remaining > 0 {
                    // A question and one concrete thing to do — never a
                    // judgement. Shame is what keeps people scrolling.
                    content.title = "Do you still want to be on your phone?"
                    content.body = (hasStreak
                        ? "Your \(streak) resets in "
                        : "Your timer resets in ")
                        + "\(PhoneFreeUsage.shortSeconds(remaining)). "
                        + "Lock your phone to keep it."
                } else {
                    content.title = "Your timer started again"
                    content.body = "That's okay. It counts up again from the "
                        + "moment you put your phone down."
                }

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
            }

            offset += PhoneFreeUsage.reminderInterval
            index += 1
        }
    }

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

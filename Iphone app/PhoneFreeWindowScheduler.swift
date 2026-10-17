//
//  PhoneFreeWindowScheduler.swift
//  Iphone app
//
//  Puts one repeating reminder on the clock for each enabled phone-free window.
//
//  The reminder is deliberately a *reminder*, not a lock: tapping it starts a
//  goal, because by then the user has already said yes to the idea. Anything
//  stricter needs the Screen Time entitlement, which is still pending.
//
//  Triggers repeat forever, so a window keeps reminding after the app has not
//  been opened for weeks. They are rebuilt from scratch every time the list
//  changes, which keeps the identifiers stable and never leaves an orphan.
//

import Foundation
import UserNotifications

@MainActor
final class PhoneFreeWindowScheduler {
    static let shared = PhoneFreeWindowScheduler()

    /// The notification action that starts a goal straight away.
    static let startActionID = "START_WINDOW"

    /// Prefix of the request identifier for each window's reminder, so the
    /// response handler can work out which window was tapped.
    static let windowRequestPrefix = "pf_window_"

    /// Only when the app is in the background or the user has pulled the app
    /// into an inactive state.
    private let startActionTitle = "Start phone-free"
    private let skipActionTitle = "Not now"
    private let categoryID = "PHONEFREE_WINDOW"

    private let center = UNUserNotificationCenter.current()

    /// Ask for permission once, when the app is first used.
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
        } catch {
            return false
        }
    }

    /// Whether reminders will actually be shown. `nil` is treated as off, so
    /// the screen can say so rather than implying reminders are working.
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    /// Must be called before any reminder can present its actions.
    func setupCategories() {
        let start = UNNotificationAction(
            identifier: Self.startActionID,
            title: startActionTitle,
            options: [.foreground]
        )

        let skip = UNNotificationAction(
            identifier: "SKIP",
            title: skipActionTitle,
            options: []
        )

        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [start, skip],
            intentIdentifiers: [],
            options: []
        )

        // One call registers every category, so the use reminders' "I've put
        // it down" button is set up here too.
        center.setNotificationCategories([
            category,
            PhoneFreeUseReminders.category,
        ])
    }

    /// Rebuilds every reminder from the current list. Safe to call often.
    ///
    /// Only window reminders are removed — goal nudges and use reminders are
    /// pending alongside them and must survive a window being edited.
    func reschedule(_ windows: [PhoneFreeWindow]) {
        Task {
            let stale = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.windowRequestPrefix) }

            center.removePendingNotificationRequests(withIdentifiers: stale)

            for window in windows where window.enabled {
                schedule(window)
            }
        }
    }

    private func schedule(_ window: PhoneFreeWindow) {
        guard let content = content(for: window) else { return }

        // `hour`/`minute` only, repeating — so the reminder comes back every
        // day at that time until it is explicitly removed. No 7-day cliff.
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(
                hour: window.startHour,
                minute: window.startMinute
            ),
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Self.windowRequestPrefix + window.id.uuidString,
            content: content,
            trigger: trigger
        )

        center.add(request, withCompletionHandler: nil)
    }

    private func content(for window: PhoneFreeWindow) -> UNNotificationContent? {
        let content = UNMutableNotificationContent()

        let label = window.label.isEmpty
            ? "Phone-free window"
            : window.label

        content.title = "Phone-free time now"
        content.body = "\(label) · \(window.summary). Tap to start — or ignore it."
        content.categoryIdentifier = categoryID
        content.sound = .default

        return content
    }
}

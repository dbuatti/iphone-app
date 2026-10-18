
import BackgroundTasks
import SwiftUI
import UserNotifications

/// Handles the tap on a phone-free window reminder. Without a delegate the
/// notification would only bring the app forward; the whole point of the
/// reminder is that one tap starts the goal.
final class PhoneFreeAppDelegate: NSObject, UIApplicationDelegate,
    UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Registering before this method returns is mandatory, and the
        // identifier must also appear in Info.plist's
        // BGTaskSchedulerPermittedIdentifiers or the call raises. This is
        // the wake that catches a lock landing while the app is suspended —
        // see PhoneFreeStore.performLockCheck().
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: PhoneFreeStore.lockCheckTaskID,
            using: nil
        ) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            PhoneFreeStore.handleLockCheckRefresh(refresh)
        }

        return true
    }

    /// While PhoneFree is on screen the bell is played by the app itself, so a
    /// notification would only double it. Silencing foreground banners keeps
    /// the sound to a single bell and leaves the app's own screens to speak.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    /// The user tapped the notification, or tapped "Start phone-free".
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == PhoneFreeUseReminders.putDownActionID {
            PhoneFreeUseReminders.putDown()
            completionHandler()
            return
        }

        let prefix = PhoneFreeWindowScheduler.windowRequestPrefix
        let identifier = response.notification.request.identifier

        let isWindow = identifier.hasPrefix(prefix)

        // Tapping the notification itself counts too, so starting a goal
        // never needs a second tap.
        let accepted = response.actionIdentifier
            == PhoneFreeWindowScheduler.startActionID
            || response.actionIdentifier
            == UNNotificationDefaultActionIdentifier

        if isWindow, accepted {
            let windowID = String(identifier.dropFirst(prefix.count))

            NotificationCenter.default.post(
                name: .phoneFreeStartFromReminder,
                object: nil,
                userInfo: ["windowID": windowID]
            )
        }

        completionHandler()
    }
}

extension Notification.Name {
    /// Posted when a window reminder is tapped. The app starts the goal.
    static let phoneFreeStartFromReminder = Notification.Name(
        "phonefreeStartFromReminder"
    )
}

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(PhoneFreeAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

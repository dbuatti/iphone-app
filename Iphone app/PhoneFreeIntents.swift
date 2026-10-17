//
//  PhoneFreeIntents.swift
//  Iphone app
//
//  The two Shortcuts actions that let PhoneFree notice other apps.
//
//  iOS will not tell an app when the phone is unlocked or when another app is
//  in use. What it *will* do is run a Shortcuts automation when a chosen app
//  opens or closes. So the user points two automations at the apps that pull
//  at them:
//
//   * "When Instagram is opened"  → I'm Using My Phone
//   * "When Instagram is closed"  → I Put My Phone Down
//
//  and PhoneFree freezes the counter, counts down the grace period with
//  reminders, and resets the streak if they are still on it at the end.
//
//  During a goal, opening a chosen app brings PhoneFree to the front instead,
//  where the promise gate is waiting.
//

import AppIntents
import Foundation
import WidgetKit

// Both actions are Live Activity intents, which is what lets them start or
// update the Lock Screen counter while PhoneFree itself stays closed.

struct StartPhoneUseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "I'm Using My Phone"

    static let description = IntentDescription(
        """
        Freezes your PhoneFree counter and starts the countdown to a reset. \
        Run it from an automation when a distracting app opens.
        """
    )

    /// Runs quietly in the background, except during a goal, when it opens
    /// PhoneFree so the promise gate can ask whether to break the promise.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    func perform() async throws -> some IntentResult {
        let now = Date()
        PhoneFreeAutomationHealth.mark(.opened, at: now)

        if PhoneFreeIntentGoal.isRunning(at: now) {
            try await continueInForeground(nil, alwaysConfirm: false)
            return .result()
        }

        var state = PhoneFreeUsage.load()
        let alreadyUsing = state.isUsing(at: now)

        state.beginUse(at: now)
        PhoneFreeUsage.save(state)

        // Moving between two watched apps keeps the same session and the same
        // countdown; only a fresh pick-up starts the reminders. With less than
        // a minute at stake there is nothing to lose, so no reminders either.
        if !alreadyUsing, state.hasStretchAtStake {
            PhoneFreeUseReminders.schedule(for: state, now: now)
        }

        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .phoneFreeUsageChanged, object: nil)
        await PhoneFreeLiveActivityManager.shared.showAwayCounter(state, now: now)

        return .result()
    }
}

struct StopPhoneUseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "I Put My Phone Down"

    static let description = IntentDescription(
        """
        Ends the phone use PhoneFree is counting. Inside the grace period your \
        streak carries on; after it, the counter starts again from zero. Run \
        it from an automation when a distracting app closes.
        """
    )

    static let supportedModes: IntentModes = .background

    func perform() async throws -> some IntentResult {
        PhoneFreeAutomationHealth.mark(.closed)
        PhoneFreeUseReminders.putDown()
        await PhoneFreeLiveActivityManager.shared.showAwayCounter(
            PhoneFreeUsage.load()
        )
        return .result()
    }
}

struct PhoneFreeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPhoneUseIntent(),
            phrases: ["I'm using my phone in \(.applicationName)"],
            shortTitle: "Using My Phone",
            systemImageName: "iphone"
        )

        AppShortcut(
            intent: StopPhoneUseIntent(),
            phrases: ["I put my phone down in \(.applicationName)"],
            shortTitle: "Put Phone Down",
            systemImageName: "iphone.slash"
        )
    }
}

/// Whether the user's Shortcuts automations are actually firing. Setting
/// them up is the fiddliest part of the app, so it is never left to faith:
/// each action notes when it last ran, and the app can say "connected",
/// "half set up" or "not set up yet".
enum PhoneFreeAutomationHealth {
    enum Signal: String {
        case opened = "phoneFreeAutomationOpenedAt"
        case closed = "phoneFreeAutomationClosedAt"
    }

    enum Status: Equatable {
        case notSetUp
        /// "Is Opened" works but "Is Closed" has never run, so the counter
        /// only restarts when a session is given up on.
        case missingClose
        case connected(lastSeen: Date)
    }

    static func mark(_ signal: Signal, at date: Date = Date()) {
        PhoneFreeUsage.defaults?.set(date, forKey: signal.rawValue)
    }

    static func lastSeen(_ signal: Signal) -> Date? {
        PhoneFreeUsage.defaults?.object(forKey: signal.rawValue) as? Date
    }

    static var status: Status {
        guard let opened = lastSeen(.opened) else { return .notSetUp }
        guard let closed = lastSeen(.closed) else { return .missingClose }
        return .connected(lastSeen: max(opened, closed))
    }
}

/// The goal as the store last saved it. The intents read it straight from the
/// shared defaults because they may run before the app has a store at all.
private enum PhoneFreeIntentGoal {
    static func isRunning(at now: Date) -> Bool {
        let defaults = PhoneFreeUsage.defaults

        guard defaults?.bool(forKey: "phoneFreeGoalActive") == true,
              let end = defaults?.object(forKey: "phoneFreeGoalEnd") as? Date
        else { return false }

        return end > now
    }
}

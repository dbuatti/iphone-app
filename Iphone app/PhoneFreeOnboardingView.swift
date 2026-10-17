//
//  PhoneFreeOnboardingView.swift
//  Iphone app
//
//  The first five screens anyone sees. Each one says one thing and asks for
//  at most one thing, with the step count always visible, so it is clear how
//  much is left — open-ended setup is where people with ADHD drop off.
//
//  Everything optional says so and can be skipped in words ("I'll do this
//  later"), and the whole introduction can be replayed from Settings.
//
//  New views use text styles rather than fixed sizes, so they follow the
//  user's text size setting.
//

import SwiftUI
import UserNotifications

struct PhoneFreeOnboardingView: View {
    @Environment(PhoneFreeStore.self) private var store

    let onFinish: () -> Void

    private enum Step: Int, CaseIterable {
        case welcome
        case rule
        case reminders
        case interrupt
        case ready
    }

    @State private var step: Step = .welcome
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var automationStatus = PhoneFreeAutomationHealth.status

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            PhoneFreeTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progress
                    .padding(.top, 12)
                    .animation(.easeInOut(duration: 0.25), value: step)

                ScrollView(showsIndicators: false) {
                    page
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 36)
                        .padding(.bottom, 24)
                        // Pages swap instantly: a cross-fade puts two pages of
                        // text on screen at once, which is noise to read past.
                        // Only the progress bar moves.
                }

                footer
                    .transaction { $0.animation = nil }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
        .task { await refreshNotificationStatus() }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from Shortcuts is the moment setup may have worked.
            if phase == .active {
                automationStatus = PhoneFreeAutomationHealth.status
            }
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await PhoneFreeWindowScheduler.shared
            .authorizationStatus()
    }

    // MARK: - Progress

    /// "Step 2 of 5" in words as well as dots, so the length is never a
    /// mystery.
    private var progress: some View {
        // At the largest text sizes the label gets its own line, so the bar
        // is never squeezed down to slivers.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))

        return layout {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(
                            item.rawValue <= step.rawValue
                                ? PhoneFreeTheme.accent
                                : Color.white.opacity(0.12)
                        )
                        .frame(height: 4)
                }
            }

            Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PhoneFreeTheme.muted)
                .fixedSize()
                .transaction { $0.animation = nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Step \(step.rawValue + 1) of \(Step.allCases.count)"
        )
    }

    // MARK: - Pages

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome:
            welcomePage
        case .rule:
            rulePage
        case .reminders:
            remindersPage
        case .interrupt:
            interruptPage
        case .ready:
            readyPage
        }
    }

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "iphone.slash")
                .font(.largeTitle)
                .foregroundStyle(PhoneFreeTheme.accent)

            title("One number: time away from your phone.")

            paragraph(
                "PhoneFree counts how long it has been since you last used "
                + "your phone. The longer it gets, the better. That's the "
                + "whole idea."
            )

            paragraph(
                "No telling off and nothing to make up for. If it goes back to "
                + "zero, you just start again."
            )
        }
    }

    private var rulePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("The one rule")

            ruleRow(
                symbol: "hand.raised",
                heading: "Pick up your phone",
                detail: "The counter pauses. It doesn't go up while you're "
                    + "using it."
            )

            ruleRow(
                symbol: "checkmark.circle",
                heading: "Put it down within "
                    + PhoneFreeUsage.words(store.resetAfter),
                detail: "Nothing lost. The counter carries on where it was."
            )

            ruleRow(
                symbol: "arrow.counterclockwise",
                heading: "Still on it after "
                    + PhoneFreeUsage.words(store.resetAfter),
                detail: "It goes back to 0, and starts counting again when "
                    + "you put the phone down."
            )

            paragraph(
                "You can change the time in Settings. A minute is enough to "
                + "check the time or answer one message."
            )
            .padding(.top, 4)
        }
    }

    private var remindersPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "bell.badge")
                .font(.largeTitle)
                .foregroundStyle(PhoneFreeTheme.accent)

            title("Let PhoneFree remind you")

            paragraph(
                "Reminders are how PhoneFree reaches you when it's closed: a "
                + "quiet nudge during a goal, and a countdown before your "
                + "timer resets."
            )

            paragraph(
                "Those two are silent. You can turn any reminder off in "
                + "Settings."
            )

            // Before the user has answered, the footer's button asks. After,
            // this says where things stand.
            if notificationStatus != .notDetermined {
                PhoneFreeNotificationStatusRow()
            }
        }
    }

    private var interruptPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                title("Interrupt other apps")

                optionalTag
            }

            paragraph(
                "iOS doesn't tell apps when you unlock your phone. Shortcuts "
                + "can tell PhoneFree when the apps that pull at you open and "
                + "close."
            )

            PhoneFreeShortcutsSetupSteps(showsOpenButton: false)

            PhoneFreeAutomationStatusRow()
        }
    }

    private var readyPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark.seal")
                .font(.largeTitle)
                .foregroundStyle(PhoneFreeTheme.accent)

            title("You're set.")

            paragraph(
                "One last idea, if you want it: put the counter on your Lock "
                + "Screen, so it's the first thing you see when you pick your "
                + "phone up."
            )

            ruleRow(
                symbol: "lock.iphone",
                heading: "Add the Lock Screen widget",
                detail: "Press and hold your Lock Screen, tap Customize, "
                    + "then add PhoneFree."
            )

            paragraph("You can see this introduction again in Settings.")
                .padding(.top, 4)
        }
    }

    // MARK: - Footer

    /// One filled button, always in the same place. Optional steps get a
    /// second, quieter way through that says plainly what it does.
    private var footer: some View {
        VStack(spacing: 6) {
            PhoneFreePrimaryButton(title: primaryTitle) {
                if step == .interrupt, !isAutomationConnected {
                    if let url = URL(string: "shortcuts://") {
                        openURL(url)
                    }
                } else if step == .reminders,
                          notificationStatus == .notDetermined {
                    Task {
                        _ = await PhoneFreeWindowScheduler.shared
                            .requestAuthorization()
                        await refreshNotificationStatus()
                        advance()
                    }
                } else {
                    advance()
                }
            }

            if let skipTitle {
                Button(skipTitle) {
                    advance()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PhoneFreeTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: "Show me how"
        case .rule: "Got it"
        case .reminders:
            notificationStatus == .notDetermined ? "Allow reminders" : "Next"
        case .interrupt: isAutomationConnected ? "Next" : "Open Shortcuts"
        case .ready: "Start using PhoneFree"
        }
    }

    private var skipTitle: String? {
        switch step {
        case .reminders where notificationStatus == .notDetermined:
            "Not now"
        case .interrupt where automationStatus == .notSetUp:
            "I'll do this later"
        case .interrupt where !isAutomationConnected:
            "Finish this later"
        default:
            nil
        }
    }

    private var isAutomationConnected: Bool {
        if case .connected = automationStatus { return true }
        return false
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else {
            onFinish()
            return
        }
        step = next
    }

    // MARK: - Pieces

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.title.weight(.semibold))
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(PhoneFreeTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var optionalTag: some View {
        Text("optional")
            .font(.caption.weight(.semibold))
            .foregroundStyle(PhoneFreeTheme.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.08), in: Capsule())
    }

    private func ruleRow(
        symbol: String,
        heading: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(PhoneFreeTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(heading)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Shared setup pieces
//
// Used here and in Settings, so the instructions and the status read the
// same wherever the user meets them.

/// The four Shortcuts steps, numbered, with a way into the Shortcuts app.
struct PhoneFreeShortcutsSetupSteps: View {
    /// Off in the introduction, where the page's main button opens Shortcuts.
    var showsOpenButton = true

    @Environment(\.openURL) private var openURL

    /// The number badges grow with the text beside them.
    @ScaledMetric(relativeTo: .caption) private var badgeSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            step(1, "In Shortcuts, tap Automation, then New Automation, then "
                + "App.")
            step(2, "Choose your apps. Tick Is Opened only, and choose Run "
                + "Immediately.")
            step(3, "Add the PhoneFree action “I'm Using My Phone”.")
            step(4, "Make a second one for the same apps with Is Closed and "
                + "“I Put My Phone Down”.")

            if showsOpenButton {
                PhoneFreeSecondaryButton(
                    title: "Open Shortcuts",
                    symbol: "square.2.layers.3d"
                ) {
                    if let url = URL(string: "shortcuts://") {
                        openURL(url)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(PhoneFreeTheme.background)
                .frame(width: badgeSize, height: badgeSize)
                .background(PhoneFreeTheme.accent, in: Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Whether the Shortcuts automations have actually run. Refreshes whenever
/// the app comes back to the front — which is exactly when someone returns
/// from testing their automation.
struct PhoneFreeAutomationStatusRow: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var status = PhoneFreeAutomationHealth.status

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(heading)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PhoneFreeTheme.card)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PhoneFreeTheme.cornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .phoneFreeUsageChanged)
        ) { _ in
            refresh()
        }
    }

    private func refresh() {
        status = PhoneFreeAutomationHealth.status
    }

    private var symbol: String {
        switch status {
        case .notSetUp: "circle.dashed"
        case .missingClose: "circle.lefthalf.filled"
        case .connected: "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch status {
        case .connected: PhoneFreeTheme.accent
        default: PhoneFreeTheme.muted
        }
    }

    private var heading: String {
        switch status {
        case .notSetUp: "Not set up yet"
        case .missingClose: "Halfway there"
        case .connected: "Connected"
        }
    }

    private var detail: String {
        switch status {
        case .notSetUp:
            "Once it's set up, open one of your chosen apps and come back. "
                + "This will change to Connected."
        case .missingClose:
            "Opening your apps works. Add the Is Closed automation (step 4) "
                + "so your counter starts again when you leave them."
        case .connected(let lastSeen):
            "Both automations work. Last heard from "
                + lastSeen.formatted(.relative(presentation: .named))
                + "."
        }
    }
}

/// Whether reminders are allowed, with the one action that fixes it.
struct PhoneFreeNotificationStatusRow: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Group {
            switch status {
            case .authorized, .provisional, .ephemeral:
                Label("Reminders are on", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(PhoneFreeTheme.accent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(PhoneFreeTheme.card)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: PhoneFreeTheme.cornerRadius,
                            style: .continuous
                        )
                    )

            case .denied:
                PhoneFreeSecondaryButton(
                    title: "Turn reminders on in Settings",
                    symbol: "gearshape",
                    tint: PhoneFreeTheme.accent
                ) {
                    if let url = URL(
                        string: UIApplication.openNotificationSettingsURLString
                    ) {
                        openURL(url)
                    }
                }

            default:
                PhoneFreeSecondaryButton(
                    title: "Allow reminders",
                    symbol: "bell",
                    tint: PhoneFreeTheme.accent
                ) {
                    Task {
                        _ = await PhoneFreeWindowScheduler.shared
                            .requestAuthorization()
                        await refresh()
                    }
                }
            }
        }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refresh() }
            }
        }
    }

    private func refresh() async {
        status = await PhoneFreeWindowScheduler.shared.authorizationStatus()
    }
}

#Preview {
    PhoneFreeOnboardingView(onFinish: {})
        .environment(PhoneFreeStore())
}

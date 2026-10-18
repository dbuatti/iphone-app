//
//  PhoneFreeSettingsView.swift
//  Iphone app
//
//  Preferences, data, and the honest status of the parts that need more from
//  Apple than a personal team can give (screen-time shields).
//

import SwiftUI
import UserNotifications

struct PhoneFreeSettingsView: View {
    @Environment(PhoneFreeStore.self) private var store

    @State private var confirmingClearAll = false
    @State private var confirmingClearToday = false
    @State private var showingWindows = false

    /// One source of truth for "will reminders actually arrive?", shared with
    /// the home screen so the two can never disagree — including the moment
    /// the user comes back from turning them on in iOS Settings.
    private var notificationStatus: UNAuthorizationStatus {
        store.reminderStatus ?? .notDetermined
    }

    @Environment(\.openURL) private var openURL

    /// The numbered circles in the Shortcuts steps grow with the text.

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header

                interruptSection

                progressSection

                soundSection

                lockScreenSection

                windowsSection

                sharingSection

                shieldSection

                dataSection

                aboutSection
            }
            .padding(.horizontal, PhoneFreeTheme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(PhoneFreeTheme.background)
        .confirmationDialog(
            "Clear everything?",
            isPresented: $confirmingClearAll,
            titleVisibility: .visible
        ) {
            Button("Clear all data", role: .destructive) {
                store.clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Your history, plan and reflections are deleted. Goals stop. "
                + "This cannot be undone."
            )
        }
        .confirmationDialog(
            "Clear today?",
            isPresented: $confirmingClearToday,
            titleVisibility: .visible
        ) {
            Button("Clear today", role: .destructive) {
                store.clearToday()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Today's numbers start again from zero. Your earlier days are "
                + "kept."
            )
        }
        .sheet(isPresented: $showingWindows) {
            PhoneFreeWindowSettingsView()
        }
        .task {
            await store.refreshReminderPermission()
        }
    }

    // MARK: - Interruptions

    private var interruptSection: some View {
        @Bindable var store = store

        return VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("WHEN YOU PICK UP YOUR PHONE")

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(
                        "Using your phone pauses the counter. Still on it after "
                        + "the time below, and it goes back to 0."
                    )
                    .font(.footnote)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    Picker("Reset after", selection: $store.resetAfter) {
                        ForEach(PhoneFreeUsage.resetAfterOptions, id: \.self) {
                            Text(PhoneFreeUsage.shortSeconds($0)).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: $store.goalNudgesEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reminders during a goal")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)

                            Text("A quiet Lock Screen nudge every few minutes.")
                                .font(.caption)
                                .foregroundStyle(PhoneFreeTheme.muted)
                        }
                    }
                    .tint(PhoneFreeTheme.accent)

                    Toggle(isOn: $store.liveCounterEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Live counter on the Lock Screen")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)

                            Text(
                                "The number you see before you unlock. It "
                                + "keeps counting up the moment your phone is "
                                + "locked, and the Dynamic Island counts down "
                                + "while you're on it."
                            )
                            .font(.caption)
                            .foregroundStyle(PhoneFreeTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(PhoneFreeTheme.accent)

                    if notificationStatus != .authorized {
                        notificationsButton
                    }
                }
            }

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Interrupt other apps")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(
                        "iOS doesn't tell apps when you unlock your phone. "
                        + "Shortcuts can tell PhoneFree when the apps that pull "
                        + "at you open and close, and PhoneFree then counts "
                        + "down with a reminder every 15 seconds."
                    )
                    .font(.caption)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    PhoneFreeShortcutsSetupSteps()

                    PhoneFreeAutomationStatusRow()
                }
            }
        }
    }

    // MARK: - How progress looks

    /// One preference, three shapes. Shown as a list rather than a picker so
    /// each choice can say what it does — the point is that it is safe to try.
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("HOW PROGRESS LOOKS")

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(
                        "Your goal, and the climb to your next target, can fill "
                        + "up in whichever shape you like. The number never "
                        + "changes — only the picture."
                    )
                    .font(.footnote)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    ForEach(PhoneFreeProgressStyle.allCases) { style in
                        optionRow(style)
                    }
                }
            }
        }
    }

    private func optionRow(_ style: PhoneFreeProgressStyle) -> some View {
        let selected = store.progressStyle == style

        return Button {
            store.play(.selection)
            store.progressStyle = style
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: style.symbol)
                    .font(.callout)
                    .foregroundStyle(PhoneFreeTheme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(style.detail)
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(
                    systemName: selected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(
                    selected
                        ? PhoneFreeTheme.accent
                        : PhoneFreeTheme.muted.opacity(0.5)
                )
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - The bell

    private var soundSection: some View {
        @Bindable var store = store

        return VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("THE BELL")

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(
                        "A short glockenspiel chime marks a timer finishing — "
                        + "the end of a task, or the end of a goal."
                    )
                    .font(.footnote)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    Toggle(isOn: $store.finishChimeEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bell when a goal finishes")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)

                            Text("One chime when the phone-free time is up. "
                                 + "It rings from a notification if PhoneFree "
                                 + "is closed.")
                            .font(.caption)
                            .foregroundStyle(PhoneFreeTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(PhoneFreeTheme.accent)

                    if store.finishChimeEnabled {
                        Toggle(isOn: $store.taskChimeEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bell at the end of each task")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)

                                Text("For plans, so a change of activity is "
                                     + "felt rather than discovered.")
                                .font(.caption)
                                .foregroundStyle(PhoneFreeTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(PhoneFreeTheme.accent)

                        Toggle(isOn: $store.chimeOverridesSilent) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sound even when muted")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)

                                Text(
                                    "PhoneFree rings the bell itself, so it "
                                    + "can sound through the Ring/Silent "
                                    + "switch while the app is open. The "
                                    + "Lock Screen notification still follows "
                                    + "your switch — iOS only lets "
                                    + "Apple-approved “critical” alerts ignore "
                                    + "it."
                                )
                                .font(.caption)
                                .foregroundStyle(PhoneFreeTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(PhoneFreeTheme.accent)

                        PhoneFreeSecondaryButton(
                            title: "Play the bell",
                            symbol: "bell"
                        ) {
                            store.previewChime()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    /// The reminders are the interruption, so without permission nothing
    /// happens. Says so, and fixes it in one tap.
    private var notificationsButton: some View {
        Button {
            if notificationStatus == .denied {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            } else {
                Task {
                    _ = await PhoneFreeWindowScheduler.shared
                        .requestAuthorization()
                    await store.refreshReminderPermission()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge")

                Text(
                    notificationStatus == .denied
                        ? "Turn on notifications in Settings"
                        : "Allow reminders"
                )
                .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(PhoneFreeTheme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .frame(minHeight: 48)
            .background(PhoneFreeTheme.accent)
            .clipShape(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SETTINGS")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(PhoneFreeTheme.accent)

            Text("How the app behaves")
                .scaledFont(26, weight: .semibold, relativeTo: .title)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Lock Screen

    private var lockScreenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("LOCK SCREEN")

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "hourglass")
                            .font(.callout)
                            .foregroundStyle(PhoneFreeTheme.accent)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("The countdown shows during a goal")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)

                            Text(
                                "Start a goal and the time remaining appears on "
                                + "your Lock Screen and Dynamic Island until it "
                                + "runs out."
                            )
                            .font(.caption)
                            .foregroundStyle(PhoneFreeTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Rectangle()
                        .fill(PhoneFreeTheme.cardBorder)
                        .frame(height: 1)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "rectangle.3.group")
                            .font(.callout)
                            .foregroundStyle(PhoneFreeTheme.accent)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("The away counter is a widget")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)

                            Text(
                                "“Since you last used your phone” never expires, "
                                + "so it lives on a Lock Screen widget rather than "
                                + "a Live Activity. Long-press your Lock Screen, "
                                + "tap Customize, and add PhoneFree."
                            )
                            .font(.caption)
                            .foregroundStyle(PhoneFreeTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sharing

    private var sharingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("TELL SOMEONE")

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        "Doing this in front of someone makes it stick. Send "
                        + "your number to a friend and ask them to check in "
                        + "on you."
                    )
                    .font(.footnote)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    ShareLink(item: shareText) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")

                            Text("Share my progress")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(PhoneFreeTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .frame(minHeight: 48)
                        .background(PhoneFreeTheme.accent)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                        )
                    }
                }
            }
        }
    }

    private var shareText: String {
        let best = PhoneFreeFormat.clock(store.bestGapToday)

        return "I'm using PhoneFree to stay off my phone. Today I've protected "
            + PhoneFreeFormat.duration(store.protectedSecondsToday)
            + " and my longest pause was \(best). "
            + "Ask me how it's going."
    }

    // MARK: - Windows

    private var windowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("PHONE-FREE WINDOWS")

            Button {
                showingWindows = true
            } label: {
                PhoneFreeCard {
                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .foregroundStyle(PhoneFreeTheme.muted)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scheduled windows & reminders")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)

                            Text(
                                "\(store.windows.filter { $0.enabled }.count) active"
                            )
                            .font(.caption)
                            .foregroundStyle(PhoneFreeTheme.muted)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(PhoneFreeTheme.muted)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Shields

    private var shieldSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("BLOCKING APPS")

            PhoneFreeCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.callout)
                        .foregroundStyle(PhoneFreeTheme.muted)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not switched on yet")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)

                        Text(
                            "Blocking other apps during a goal needs Apple's "
                            + "Screen Time permission, which they grant case by "
                            + "case. It's the next thing on the list."
                        )
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                        Text(
                            "For now, the Shortcuts interruption above is the "
                            + "closest thing — and putting the phone in "
                            + "another room."
                        )
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("YOUR DATA")

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        "Everything lives on this phone. There's no account and "
                        + "nothing is sent anywhere."
                    )
                    .font(.footnote)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    Button {
                        confirmingClearToday = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")

                            Text("Start today again")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .frame(minHeight: 48)
                        .background(Color.white.opacity(0.06))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        confirmingClearAll = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")

                            Text("Clear everything")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(PhoneFreeTheme.caution)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .frame(minHeight: 48)
                        .background(Color.white.opacity(0.04))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("ABOUT")

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PhoneFree")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(
                        "A timer, a bit of friction, and a place to put the "
                        + "time you get back. Made for people whose brains "
                        + "make this harder than it looks."
                    )
                    .font(.footnote)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    PhoneFreeSecondaryButton(
                        title: "Show the introduction again",
                        symbol: "sparkles"
                    ) {
                        store.showingOnboarding = true
                    }
                    .padding(.vertical, 4)

                    Text(appVersion)
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted.opacity(0.7))
                }
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary

        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"

        return "Version \(version) (\(build))"
    }
}

#Preview {
    PhoneFreeSettingsView()
        .environment(PhoneFreeStore())
        .preferredColorScheme(.dark)
}

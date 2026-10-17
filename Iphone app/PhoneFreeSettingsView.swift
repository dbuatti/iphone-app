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
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    @Environment(\.openURL) private var openURL

    /// The numbered circles in the Shortcuts steps grow with the text.
    @ScaledMetric(relativeTo: .caption) private var stepBadgeSize: CGFloat = 20

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header

                interruptSection

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
            notificationStatus = await PhoneFreeWindowScheduler.shared
                .authorizationStatus()
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

                    VStack(alignment: .leading, spacing: 8) {
                        setupStep(1, "In Shortcuts, tap Automation, then New "
                            + "Automation, then App.")
                        setupStep(2, "Choose your apps. Tick Is Opened only, "
                            + "and choose Run Immediately.")
                        setupStep(3, "Add the PhoneFree action “I'm Using My "
                            + "Phone”.")
                        setupStep(4, "Make a second one for the same apps with "
                            + "Is Closed and “I Put My Phone Down”.")
                    }

                    Button {
                        if let url = URL(string: "shortcuts://") {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.2.layers.3d")

                            Text("Open Shortcuts")
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
                }
            }
        }
    }

    private func setupStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(PhoneFreeTheme.background)
                .frame(width: stepBadgeSize, height: stepBadgeSize)
                .background(PhoneFreeTheme.accent, in: Circle())

            Text(text)
                .font(.footnote)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
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
                    notificationStatus = await PhoneFreeWindowScheduler.shared
                        .authorizationStatus()
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
                                + "tap Customize, and add The Pause."
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
                            + "Screen Time permission, which they grant review "
                            + "-by-review. It's the next thing on the list."
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
                        .foregroundStyle(Color(red: 0.93, green: 0.55, blue: 0.55))
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

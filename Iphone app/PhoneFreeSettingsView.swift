//
//  PhoneFreeSettingsView.swift
//  Iphone app
//
//  Preferences, data, and the honest status of the parts that need more from
//  Apple than a personal team can give (screen-time shields).
//

import SwiftUI

struct PhoneFreeSettingsView: View {
    @Environment(PhoneFreeStore.self) private var store

    @State private var confirmingClearAll = false
    @State private var confirmingClearToday = false
    @State private var showingWindows = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header

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
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SETTINGS")
                .font(.system(size: 12, weight: .bold))
                .tracking(3)
                .foregroundStyle(PhoneFreeTheme.accent)

            Text("How the app behaves")
                .font(.system(size: 26, weight: .semibold))
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
                            .font(.system(size: 16))
                            .foregroundStyle(PhoneFreeTheme.accent)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("The countdown shows during a goal")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)

                            Text(
                                "Start a goal and the time remaining appears on "
                                + "your Lock Screen and Dynamic Island until it "
                                + "runs out."
                            )
                            .font(.system(size: 12))
                            .foregroundStyle(PhoneFreeTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Rectangle()
                        .fill(PhoneFreeTheme.cardBorder)
                        .frame(height: 1)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 16))
                            .foregroundStyle(PhoneFreeTheme.accent)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("The away counter is a widget")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)

                            Text(
                                "“Since you last used your phone” never expires, "
                                + "so it lives on a Lock Screen widget rather than "
                                + "a Live Activity. Long-press your Lock Screen, "
                                + "tap Customize, and add The Pause."
                            )
                            .font(.system(size: 12))
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
                    .font(.system(size: 13))
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    ShareLink(item: shareText) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")

                            Text("Share my progress")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(PhoneFreeTheme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
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
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)

                            Text(
                                "\(store.windows.filter { $0.enabled }.count) active"
                            )
                            .font(.system(size: 12))
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
                        .font(.system(size: 16))
                        .foregroundStyle(PhoneFreeTheme.muted)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not switched on yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)

                        Text(
                            "Blocking other apps during a goal needs Apple's "
                            + "Screen Time permission, which they grant review "
                            + "-by-review. It's the next thing on the list."
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                        Text(
                            "For now, the friction is the pause and the "
                            + "counter — and putting the phone in another room."
                        )
                        .font(.system(size: 12))
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
                    .font(.system(size: 13))
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    Button {
                        confirmingClearToday = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")

                            Text("Start today again")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
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
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(Color(red: 0.93, green: 0.55, blue: 0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(
                        "A timer, a bit of friction, and a place to put the "
                        + "time you get back. Made for people whose brains "
                        + "make this harder than it looks."
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(appVersion)
                        .font(.system(size: 12))
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

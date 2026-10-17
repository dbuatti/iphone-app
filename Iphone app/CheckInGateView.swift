//
//  CheckInGateView.swift
//  Iphone app
//
//  The "are you sure?" gate. Shown whenever the app is opened after a
//  meaningful stretch away, when no phone-free goal is running.
//
//  It confronts the user with how long they lasted, and makes the cost of
//  continuing explicit: stay on the phone past the grace period and the timer
//  restarts at zero.
//

import SwiftUI

struct CheckInGateView: View {
    let awayFor: TimeInterval
    let bestToday: TimeInterval
    let resetAfter: TimeInterval

    let onPutItDown: () -> Void
    let onUseAnyway: () -> Void

    private let background = PhoneFreeTheme.background
    private let accent = PhoneFreeTheme.accent
    private let muted = PhoneFreeTheme.muted

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "hourglass")
                    .font(.system(size: 32))
                    .foregroundStyle(accent)

                Text("You were away for")
                    .font(.system(size: 15))
                    .foregroundStyle(muted)
                    .padding(.top, 18)

                Text(formatDuration(awayFor))
                    .font(
                        .system(
                            size: 56,
                            weight: .light,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.top, 2)

                Text("Are you sure you want to use your phone now?")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 26)

                Text(
                    "Still on it in "
                    + PhoneFreeUsage.words(resetAfter)
                    + " and your timer goes back to 0."
                )
                    .font(.system(size: 14))
                    .foregroundStyle(muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                // Today's best, not today's count: a tally of pick-ups turns
                // into something to check and feel bad about.
                if bestToday >= 60 {
                    Text(
                        "Your best stretch today is "
                        + formatDuration(bestToday) + "."
                    )
                        .font(.system(size: 12))
                        .foregroundStyle(muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button(action: onPutItDown) {
                        Text("I'll put it down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(accent)
                            .clipShape(RoundedRectangle(cornerRadius: 17))
                    }
                    .buttonStyle(.plain)

                    Button(action: onUseAnyway) {
                        Text("Use it anyway")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.white.opacity(0.12), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .preferredColorScheme(.dark)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60

        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                remainder
            )
        }

        return String(format: "%02d:%02d", minutes, remainder)
    }
}

#Preview {
    CheckInGateView(
        awayFor: 4 * 3600 + 12 * 60 + 33,
        bestToday: 5 * 3600 + 2 * 60,
        resetAfter: 60,
        onPutItDown: {},
        onUseAnyway: {}
    )
}

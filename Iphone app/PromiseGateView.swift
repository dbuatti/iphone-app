//
//  PromiseGateView.swift
//  Iphone app
//
//  The friction layer. Shown whenever the app is opened while a phone-free
//  goal is running. Ending the goal early is deliberately slow: the user must
//  actively hold a button and then wait out a countdown.
//
//  Slow, but never shaming. Ending early is the user's choice, not a moral
//  failure, so there is no red, no "broken promise", and no tally of how
//  often they reached for the phone — guilt is what drives the next scroll,
//  and for OCD it can turn a goal into a rule that must not be broken.
//

import SwiftUI

struct PromiseGateView: View {
    let goalEnd: Date
    let goalMinutes: Int

    let onKeepGoing: () -> Void
    let onBreakPromise: () -> Void

    private enum Stage {
        case gate
        case confirm
    }

    @State private var stage: Stage = .gate
    @State private var isHolding = false
    @State private var cooldownStart: Date?

    private let background = PhoneFreeTheme.background
    private let accent = PhoneFreeTheme.accent
    private let muted = PhoneFreeTheme.muted

    private let holdDuration: Double = 3
    private let cooldownSeconds: Double = 10

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            switch stage {
            case .gate:
                gate
            case .confirm:
                confirm
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Stage 1: the gate

    private var gate: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 34))
                .foregroundStyle(accent)

            VStack(spacing: 10) {
                Text("You're in a phone-free goal.")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)

                Text(
                    "You picked up your phone. That's okay. Urges usually "
                    + "fade within a minute or two if you wait them out."
                )
                    .font(.system(size: 14))
                    .foregroundStyle(muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 18)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(
                    goalEnd.timeIntervalSince(context.date),
                    0
                )

                let elapsedMinutes = max(
                    0,
                    goalMinutes - Int(ceil(remaining / 60))
                )

                VStack(spacing: 6) {
                    Text(formatTime(remaining))
                        .font(
                            .system(
                                size: 58,
                                weight: .light,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("\(elapsedMinutes) OF \(goalMinutes) MIN")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(accent)
                }
            }
            .padding(.top, 34)

            Spacer()

            VStack(spacing: 14) {
                Button(action: onKeepGoing) {
                    Text("Keep going")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)

                Button {
                    stage = .confirm
                } label: {
                    Text("End goal early")
                        .font(.system(size: 14))
                        .foregroundStyle(muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    // MARK: - Stage 2: the deliberate, slow break

    private var confirm: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("End this goal early?")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)

            Text(
                "The time you've already protected still counts. Take a "
                + "breath first — you can always start another goal."
            )
                .font(.system(size: 14))
                .foregroundStyle(muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Spacer()

            if let cooldownStart {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(
                        cooldownSeconds - context.date.timeIntervalSince(
                            cooldownStart
                        ),
                        0
                    )
                    let ready = left <= 0

                    Button {
                        onBreakPromise()
                    } label: {
                        Text(
                            ready
                                ? "Yes, end it now"
                                : "Wait \(Int(ceil(left)))s…"
                        )
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(ready ? 1 : 0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            .white.opacity(ready ? 0.12 : 0.05)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                    }
                    .buttonStyle(.plain)
                    .disabled(!ready)
                }
            } else {
                holdToUnlock
            }

            Button {
                stage = .gate
                isHolding = false
                cooldownStart = nil
            } label: {
                Text("Keep going instead")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    private var holdToUnlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17)
                .fill(.white.opacity(0.06))

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 17)
                    .fill(accent.opacity(0.85))
                    .frame(
                        width: geo.size.width * (isHolding ? 1 : 0)
                    )
                    .animation(
                        .linear(duration: isHolding ? holdDuration : 0.2),
                        value: isHolding
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 17))

            Text(isHolding ? "Keep holding…" : "Hold for 3 seconds to continue")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(height: 58)
        .contentShape(RoundedRectangle(cornerRadius: 17))
        // The fill animation above is cosmetic. The only thing that can
        // unlock the button is `perform`, which SwiftUI fires strictly after
        // `minimumDuration` of continuous pressing — so a quick tap, or a
        // finger that drifts away, cannot get through.
        .onLongPressGesture(
            minimumDuration: holdDuration,
            maximumDistance: 60
        ) {
            isHolding = false
            cooldownStart = Date()
        } onPressingChanged: { pressing in
            isHolding = pressing
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
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
    PromiseGateView(
        goalEnd: Date().addingTimeInterval(12 * 60),
        goalMinutes: 20,
        onKeepGoing: {},
        onBreakPromise: {}
    )
}

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

            PhoneFreeFillingScroll {
                switch stage {
                case .gate:
                    gate
                case .confirm:
                    confirm
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Stage 1: the gate

    private var gate: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.largeTitle)
                .foregroundStyle(accent)

            VStack(spacing: 10) {
                Text("You're in a phone-free goal.")
                    .scaledFont(27, weight: .semibold, relativeTo: .title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(
                    "You picked up your phone. That's okay. Urges usually "
                    + "fade within a minute or two if you wait them out."
                )
                    .scaledFont(14, relativeTo: .subheadline)
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
                        .scaledFont(58, weight: .light, design: .rounded, relativeTo: .largeTitle)
                        .monospacedDigit()
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        .foregroundStyle(.white)

                    Text("\(elapsedMinutes) OF \(goalMinutes) MIN")
                        .font(.caption2.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(accent)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 34)

            Spacer()

            VStack(spacing: 14) {
                Button(action: onKeepGoing) {
                    Text("Keep going")
                        .font(.callout.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .frame(minHeight: 58)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)

                Button {
                    stage = .confirm
                } label: {
                    Text("End goal early")
                        .scaledFont(14, relativeTo: .subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
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
                .scaledFont(25, weight: .semibold, relativeTo: .title2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(
                "The time you've already protected still counts. Take a "
                + "breath first — you can always start another goal."
            )
                .scaledFont(14, relativeTo: .subheadline)
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
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(ready ? 1 : 0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .frame(minHeight: 58)
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
                    .scaledFont(14, weight: .medium, relativeTo: .subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .frame(minHeight: 48)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    private var holdToUnlock: some View {
        Text(isHolding ? "Keep holding…" : "Hold for 3 seconds to continue")
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
            .background {
                ZStack(alignment: .leading) {
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
                }
                .clipShape(RoundedRectangle(cornerRadius: 17))
            }
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

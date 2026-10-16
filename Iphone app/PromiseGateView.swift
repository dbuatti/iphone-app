//
//  PromiseGateView.swift
//  Iphone app
//
//  The friction layer. Shown whenever the app is opened while a phone-free
//  goal is running. Ending the goal early is deliberately slow: the user must
//  actively hold a button and then wait out a countdown.
//

import SwiftUI

struct PromiseGateView: View {
    let goalEnd: Date
    let goalMinutes: Int
    let reachedToday: Int

    let onKeepGoing: () -> Void
    let onBreakPromise: () -> Void

    private enum Stage {
        case gate
        case confirm
    }

    @State private var stage: Stage = .gate
    @State private var holdProgress: CGFloat = 0
    @State private var isHolding = false
    @State private var cooldownStart: Date?

    private let background = Color(
        red: 0.055,
        green: 0.065,
        blue: 0.12
    )

    private let accent = Color(
        red: 0.65,
        green: 0.91,
        blue: 0.79
    )

    private let muted = Color(
        red: 0.62,
        green: 0.65,
        blue: 0.74
    )

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
                Text("You're in a promise.")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)

                Text("You picked up your phone. That's okay —\nthe urge passes in about 90 seconds.")
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

            if reachedToday > 0 {
                Text(
                    "You've reached for your phone \(reachedToday) "
                    + (reachedToday == 1 ? "time" : "times") + " today."
                )
                .font(.system(size: 13))
                .foregroundStyle(muted)
                .multilineTextAlignment(.center)
                .padding(.top, 22)
            }

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

            Text("Break your promise?")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)

            Text("Going back now means the time you've\nalready protected still counts — but you'll end early.")
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
                                ? "Yes, break my promise"
                                : "Wait \(Int(ceil(left)))s…"
                        )
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ready ? .white : muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            ready
                                ? Color(red: 0.85, green: 0.35, blue: 0.35)
                                : .white.opacity(0.05)
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
                holdProgress = 0
                isHolding = false
                cooldownStart = nil
            } label: {
                Text("Take me back")
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
                    .frame(width: geo.size.width * holdProgress)
            }
            .clipShape(RoundedRectangle(cornerRadius: 17))

            Text(isHolding ? "Keep holding…" : "Hold to unlock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(height: 58)
        .contentShape(RoundedRectangle(cornerRadius: 17))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isHolding else { return }
                    isHolding = true
                    holdProgress = 0

                    withAnimation(.linear(duration: holdDuration)) {
                        holdProgress = 1
                    }
                }
                .onEnded { _ in
                    isHolding = false

                    if holdProgress >= 0.99 {
                        cooldownStart = Date()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            holdProgress = 0
                        }
                    }
                }
        )
        .onLongPressGesture(
            minimumDuration: holdDuration,
            maximumDistance: 60,
            perform: {
                if cooldownStart == nil {
                    cooldownStart = Date()
                }
                holdProgress = 1
            },
            onPressingChanged: { pressing in
                isHolding = pressing
            }
        )
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
        reachedToday: 4,
        onKeepGoing: {},
        onBreakPromise: {}
    )
}

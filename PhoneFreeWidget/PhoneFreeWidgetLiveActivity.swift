//
//  PhoneFreeWidgetLiveActivity.swift
//  PhoneFreeWidget
//
//  The Lock Screen and Dynamic Island face of the app.
//
//  Two jobs:
//   1. While a goal is running: count down, and show *what you're meant to be
//      doing right now* with its icon punched out of a solid circle.
//   2. With no goal running: count *up* from the last time the phone was used.
//      That number is the app's whole point, so it lives on the Lock Screen
//      where it is seen every time the phone is picked up.
//
//  PhoneFreeWidgetAttributes lives in Shared/PhoneFreeLiveActivityAttributes.swift
//  so that both the app and this extension compile the exact same type.
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Look

private enum LAColor {
    /// The app's near-black indigo. Used as the card background, and as ink on
    /// the accent background.
    static let background = Color(red: 0.043, green: 0.039, blue: 0.086)

    /// Electric violet — the app's live accent on the Lock Screen.
    static let violet = Color(red: 0.62, green: 0.49, blue: 1.0)

    /// Electric lime — reserved for earned rewards (surplus).
    static let lime = Color(red: 0.76, green: 1.0, blue: 0.34)
}

/// A solid circle in the accent colour with the activity's symbol cut out of
/// it, so the icon reads as a hole punched through rather than a line drawing.
///
/// The knockout colour has to match whatever sits behind it: the near-black
/// card on the Lock Screen, black inside the Dynamic Island.
private struct KnockedOutActivityBadge: View {
    let symbol: String
    var diameter: CGFloat = 46
    var knockout: Color = LAColor.background
    var tint: Color = LAColor.violet

    var body: some View {
        ZStack {
            Circle()
                .fill(tint)

            Image(systemName: symbol)
                .font(
                    .system(
                        size: diameter * 0.44,
                        weight: .bold
                    )
                )
                .foregroundStyle(knockout)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

// MARK: - The activity

struct PhoneFreeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PhoneFreeWidgetAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(LAColor.background)
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.countsUp {
                        let phase = counterPhase(
                            context.state,
                            isStale: context.isStale
                        )

                        Image(systemName: phaseSymbol(phase))
                            .font(.title3)
                            .foregroundStyle(phaseTint(phase))
                    } else {
                        Image(systemName: "iphone.slash")
                            .font(.title3)
                            .foregroundStyle(LAColor.violet)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    countText(context.state, isStale: context.isStale)
                        .font(
                            .system(
                                size: 22,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: 110, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context.state, isStale: context.isStale)
                }

            } compactLeading: {
                if context.state.countsUp {
                    let phase = counterPhase(
                        context.state,
                        isStale: context.isStale
                    )

                    Image(systemName: phaseSymbol(phase))
                        .foregroundStyle(phaseTint(phase))
                } else {
                    Image(systemName: "iphone.slash")
                        .foregroundStyle(LAColor.violet)
                }

            } compactTrailing: {
                countText(context.state, isStale: context.isStale)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: 56)

            } minimal: {
                if !context.state.countsUp,
                   let segment = context.state.currentSegment(at: Date()) {
                    KnockedOutActivityBadge(
                        symbol: segment.symbol,
                        diameter: 24,
                        knockout: .black
                    )
                } else if context.state.countsUp,
                          context.state.shieldLeft != nil {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(LAColor.lime)
                } else {
                    Image(systemName: "iphone.slash")
                        .foregroundStyle(LAColor.violet)
                }
            }
            .keylineTint(
                context.state.countsUp && context.state.shieldLeft != nil
                    ? LAColor.lime
                    : LAColor.violet
            )
        }
    }

    // MARK: Lock Screen

    @ViewBuilder
    private func lockScreen(
        _ state: PhoneFreeWidgetAttributes.ContentState
    ) -> some View {
        if state.countsUp {
            checkInLockScreen(state)
        } else {
            goalLockScreen(state)
        }
    }

    // MARK: Away counter phases

    /// What the away counter is doing. The paused state carries its own
    /// stale date, so the switch to "reset" happens in the Dynamic Island at
    /// the right second even though the app is not running.
    private enum CounterPhase {
        case counting(since: Date)
        case paused(
            frozen: TimeInterval,
            usingSince: Date,
            resetsAt: Date,
            shieldLeft: TimeInterval?
        )
        case reset
    }

    private func counterPhase(
        _ state: PhoneFreeWidgetAttributes.ContentState,
        isStale: Bool
    ) -> CounterPhase {
        guard let resetsAt = state.resetsAt,
              let frozen = state.pausedSeconds else {
            return .counting(since: state.startDate)
        }

        if isStale || resetsAt <= Date() {
            return .reset
        }

        return .paused(
            frozen: frozen,
            usingSince: state.startDate,
            resetsAt: resetsAt,
            shieldLeft: state.shieldLeft
        )
    }

    /// A clock counting up from `since`, always as h:mm:ss / m:ss. The plain
    /// `.timer` style can collapse to "<1 minute" on the Lock Screen, which is
    /// not the number someone should see before they unlock.
    private func countUp(from since: Date) -> Text {
        Text(
            timerInterval: since...since.addingTimeInterval(30 * 86_400),
            countsDown: false,
            showsHours: true
        )
    }

    /// The number that answers "how long since I last used this?" on the Lock
    /// Screen — the surface you look at with the phone already down.
    ///
    /// It always counts *up*, from the stretch that was frozen if a session is
    /// still open. Locking the phone therefore starts the timer at the number
    /// that was earned, instead of running a countdown that iOS freezes at
    /// 0:00 the moment the app is suspended. The countdown is the Dynamic
    /// Island's job — it is the "you're on your phone" version of the same
    /// number, and it is on screen over whatever app is open.
    private func checkInLockScreen(
        _ state: PhoneFreeWidgetAttributes.ContentState
    ) -> some View {
        let shielded = state.shieldLeft != nil
        let tint = shielded ? LAColor.lime : LAColor.violet
        let symbol = shielded ? "bolt.fill" : "iphone.slash"

        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))

                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 1) {
                Text("PHONEFREE")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2.6)
                    .foregroundStyle(LAColor.violet)

                countUp(from: awayAnchor(state))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(
                    shielded
                        ? "Free time is protecting your streak"
                        : "Since you last used your phone"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    /// Where the Lock Screen counts up from. With a session open it is the
    /// stretch that was frozen: `startDate` is when the phone was picked up,
    /// and `pausedSeconds` is how much was already earned before that.
    private func awayAnchor(
        _ state: PhoneFreeWidgetAttributes.ContentState
    ) -> Date {
        guard let frozen = state.pausedSeconds, state.resetsAt != nil else {
            return state.startDate
        }

        return state.startDate.addingTimeInterval(-frozen)
    }

    private func phaseSymbol(_ phase: CounterPhase) -> String {
        switch phase {
        case .counting: "iphone.slash"
        case .paused(_, _, _, let shieldLeft):
            shieldLeft != nil ? "bolt.fill" : "pause.fill"
        case .reset: "arrow.counterclockwise"
        }
    }

    /// Lime while earned free time is paying for the session, violet
    /// otherwise. Reserving lime for rewards is the whole point of it.
    private func phaseTint(_ phase: CounterPhase) -> Color {
        if case .paused(_, _, _, let shieldLeft) = phase, shieldLeft != nil {
            return LAColor.lime
        }

        return LAColor.violet
    }

    /// One line under the number, in words. This is the Dynamic Island
    /// version — the one that sits over whatever app is open — so while the
    /// phone is in use it counts down to the reset, and when banked free time
    /// is paying for it, it says so.
    @ViewBuilder
    private func phaseCaption(_ phase: CounterPhase) -> some View {
        switch phase {
        case .counting:
            Text("Since you last used your phone")
        case .paused(_, let usingSince, let resetsAt, let shieldLeft):
            HStack(spacing: 4) {
                if shieldLeft != nil {
                    Image(systemName: "bolt.fill")
                    Text("Free time ·")
                } else {
                    Text("On your phone · resets in")
                }

                Text(timerInterval: usingSince...resetsAt, countsDown: true)
                    .monospacedDigit()

                if shieldLeft != nil {
                    Text("left")
                }
            }
        case .reset:
            Text("Starts again when you put it down")
        }
    }

    /// A goal is running: count down, and show the current activity.
    private func goalLockScreen(
        _ state: PhoneFreeWidgetAttributes.ContentState
    ) -> some View {
        let segment = state.currentSegment(at: Date())

        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 6)

                Circle()
                    .trim(
                        from: 0,
                        to: progress(
                            start: state.startDate,
                            end: state.endDate
                        )
                    )
                    .stroke(
                        LAColor.violet,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: "iphone.slash")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(LAColor.violet)
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 3) {
                Text("PHONEFREE")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2.6)
                    .foregroundStyle(LAColor.violet)

                Text(state.endDate, style: .timer)
                    .font(
                        .system(size: 42, weight: .bold, design: .rounded)
                    )
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(
                    coachMessage(
                        start: state.startDate,
                        end: state.endDate
                    )
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            if let segment {
                VStack(spacing: 6) {
                    KnockedOutActivityBadge(
                        symbol: segment.symbol,
                        diameter: 52
                    )

                    Text(segment.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 68)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    // MARK: Dynamic Island bottom

    @ViewBuilder
    private func expandedBottom(
        _ state: PhoneFreeWidgetAttributes.ContentState,
        isStale: Bool
    ) -> some View {
        if state.countsUp {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PHONEFREE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(LAColor.violet)

                    phaseCaption(counterPhase(state, isStale: isStale))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        } else {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PHONEFREE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(LAColor.violet)

                    Text(
                        coachMessage(
                            start: state.startDate,
                            end: state.endDate
                        )
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                }

                Spacer(minLength: 0)

                if let segment = state.currentSegment(at: Date()) {
                    HStack(spacing: 8) {
                        Text(segment.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        KnockedOutActivityBadge(
                            symbol: segment.symbol,
                            diameter: 32,
                            knockout: .black
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Counts down to the goal, or shows the away counter. While the phone
    /// is in use the Dynamic Island counts down to the reset instead — it is
    /// on screen over whatever app is open, which is where it matters.
    @ViewBuilder
    private func countText(
        _ state: PhoneFreeWidgetAttributes.ContentState,
        isStale: Bool
    ) -> some View {
        if state.countsUp {
            switch counterPhase(state, isStale: isStale) {
            case .counting(let since):
                countUp(from: since)
            case .paused(_, let usingSince, let resetsAt, _):
                Text(timerInterval: usingSince...resetsAt, countsDown: true)
            case .reset:
                Text("0:00")
            }
        } else {
            Text(state.endDate, style: .timer)
        }
    }

    // MARK: Helpers

    private func progress(start: Date, end: Date) -> CGFloat {
        let total = end.timeIntervalSince(start)

        guard total > 0 else { return 0 }

        let elapsed = Date().timeIntervalSince(start)

        return CGFloat(min(max(elapsed / total, 0), 1))
    }

    /// Coaching copy that is recalculated every time the Lock Screen or Dynamic
    /// Island renders the activity — which, in practice, is every time the user
    /// picks the phone up. That is exactly when we want to talk to them.
    private func coachMessage(start: Date, end: Date) -> String {
        let total = end.timeIntervalSince(start)

        guard total > 0 else { return "Stay with the moment." }

        let remaining = end.timeIntervalSince(Date())

        if remaining <= 0 { return "You did it. Well done." }

        let elapsed = total - remaining
        let fraction = min(max(elapsed / total, 0), 1)
        let minutesLeft = max(1, Int(ceil(remaining / 60)))

        switch fraction {
        case ..<0.1:
            return "You just put it down. Nice."
        case ..<0.35:
            return "The urge passes. Stay with it."
        case ..<0.6:
            return "This is the hard part."
        case ..<0.85:
            return "More than halfway — \(minutesLeft) min to go."
        default:
            return "Nearly there — \(minutesLeft) min left."
        }
    }
}

// MARK: - Previews

#Preview(
    "Goal",
    as: .content,
    using: PhoneFreeWidgetAttributes(name: "PhoneFree")
) {
    PhoneFreeWidgetLiveActivity()
} contentStates: {
    PhoneFreeWidgetAttributes.ContentState(
        startDate: .now,
        endDate: .now.addingTimeInterval(20 * 60),
        goalMinutes: 20,
        segments: [
            PhoneFreeActivitySegment(
                name: "Read",
                symbol: "book.fill",
                start: .now,
                end: .now.addingTimeInterval(10 * 60)
            ),
            PhoneFreeActivitySegment(
                name: "Yoga",
                symbol: "figure.yoga",
                start: .now.addingTimeInterval(10 * 60),
                end: .now.addingTimeInterval(20 * 60)
            )
        ]
    )
}

#Preview(
    "Away counter",
    as: .content,
    using: PhoneFreeWidgetAttributes(name: "PhoneFree")
) {
    PhoneFreeWidgetLiveActivity()
} contentStates: {
    PhoneFreeWidgetAttributes.ContentState(
        startDate: .now.addingTimeInterval(-3 * 3600 - 12 * 60),
        endDate: .now,
        goalMinutes: 0,
        segments: [],
        countsUp: true
    )
    PhoneFreeWidgetAttributes.ContentState(
        startDate: .now,
        endDate: .now,
        goalMinutes: 0,
        segments: [],
        countsUp: true,
        pausedSeconds: 3 * 3600 + 12 * 60,
        resetsAt: .now.addingTimeInterval(60)
    )
}

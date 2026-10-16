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
    static let background = Color(red: 0.055, green: 0.065, blue: 0.12)
    static let mint = Color(red: 0.65, green: 0.91, blue: 0.79)
}

/// A solid circle in the accent colour with the activity's symbol cut out of
/// it, so the icon reads as a hole punched through rather than a line drawing.
///
/// The knockout colour has to match whatever sits behind it: the navy tint on
/// the Lock Screen, black inside the Dynamic Island.
private struct KnockedOutActivityBadge: View {
    let symbol: String
    var diameter: CGFloat = 46
    var knockout: Color = LAColor.background
    var tint: Color = LAColor.mint

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
                    Image(systemName: "iphone.slash")
                        .font(.title3)
                        .foregroundStyle(LAColor.mint)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    countText(context.state)
                        .font(
                            .system(
                                size: 18,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: 90, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context.state)
                }

            } compactLeading: {
                Image(systemName: "iphone.slash")
                    .foregroundStyle(LAColor.mint)

            } compactTrailing: {
                countText(context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 50)

            } minimal: {
                if !context.state.countsUp,
                   let segment = context.state.currentSegment(at: Date()) {
                    KnockedOutActivityBadge(
                        symbol: segment.symbol,
                        diameter: 24,
                        knockout: .black
                    )
                } else {
                    Image(systemName: "iphone.slash")
                        .foregroundStyle(LAColor.mint)
                }
            }
            .keylineTint(LAColor.mint)
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

    /// No goal: the number that answers "how long since I last used this?".
    private func checkInLockScreen(
        _ state: PhoneFreeWidgetAttributes.ContentState
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LAColor.mint.opacity(0.15))

                Image(systemName: "iphone.slash")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(LAColor.mint)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text("PHONEFREE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(LAColor.mint)

                Text(state.startDate, style: .timer)
                    .font(
                        .system(size: 30, weight: .medium, design: .rounded)
                    )
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("Since you last used your phone")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
    }

    /// A goal is running: count down, and show the current activity.
    private func goalLockScreen(
        _ state: PhoneFreeWidgetAttributes.ContentState
    ) -> some View {
        let segment = state.currentSegment(at: Date())

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 5)

                Circle()
                    .trim(
                        from: 0,
                        to: progress(
                            start: state.startDate,
                            end: state.endDate
                        )
                    )
                    .stroke(
                        LAColor.mint,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: "iphone.slash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(LAColor.mint)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 5) {
                Text("PHONEFREE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(LAColor.mint)

                Text(state.endDate, style: .timer)
                    .font(
                        .system(size: 29, weight: .medium, design: .rounded)
                    )
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(
                    coachMessage(
                        start: state.startDate,
                        end: state.endDate
                    )
                )
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            if let segment {
                VStack(spacing: 6) {
                    KnockedOutActivityBadge(symbol: segment.symbol)

                    Text(segment.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 64)
            }
        }
        .padding(18)
    }

    // MARK: Dynamic Island bottom

    @ViewBuilder
    private func expandedBottom(
        _ state: PhoneFreeWidgetAttributes.ContentState
    ) -> some View {
        if state.countsUp {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PHONEFREE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(LAColor.mint)

                    Text("Away since you last used your phone")
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
                        .foregroundStyle(LAColor.mint)

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

    /// Counts down to the goal, or up since the last phone use.
    @ViewBuilder
    private func countText(
        _ state: PhoneFreeWidgetAttributes.ContentState
    ) -> some View {
        if state.countsUp {
            Text(state.startDate, style: .timer)
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
}

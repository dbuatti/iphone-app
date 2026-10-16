
import ActivityKit
import WidgetKit
import SwiftUI

// `PhoneFreeWidgetAttributes` lives in Shared/PhoneFreeLiveActivityAttributes.swift
// so that both the app and this extension compile the exact same type.

struct PhoneFreeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PhoneFreeWidgetAttributes.self) { context in

            // Lock Screen presentation
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 5)

                    Circle()
                        .trim(
                            from: 0,
                            to: progress(
                                start: context.state.startDate,
                                end: context.state.endDate
                            )
                        )
                        .stroke(
                            Color.mint,
                            style: StrokeStyle(
                                lineWidth: 5,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "iphone.slash")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.mint)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text("PHONEFREE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.mint)

                    Text(context.state.endDate, style: .timer)
                        .font(.system(size: 29, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if let segment = context.state.currentSegment(at: Date()) {
                        HStack(spacing: 5) {
                            Image(systemName: segment.symbol)

                            Text(
                                "\(segment.name) · "
                                + "\(minutesRemaining(until: segment.end)) min"
                            )
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.mint)
                        .lineLimit(1)
                    }

                    Text(
                        coachMessage(
                            start: context.state.startDate,
                            end: context.state.endDate
                        )
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
            .activityBackgroundTint(Color(red: 0.055, green: 0.065, blue: 0.12))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in

            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "iphone.slash")
                        .font(.title2)
                        .foregroundStyle(.mint)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endDate, style: .timer)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PHONEFREE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(.mint)

                            if let segment = context.state.currentSegment(at: Date()) {
                                HStack(spacing: 5) {
                                    Image(systemName: segment.symbol)

                                    Text(segment.name)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            }

                            Text(
                                coachMessage(
                                    start: context.state.startDate,
                                    end: context.state.endDate
                                )
                            )
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                        }

                        Spacer()

                        Text("\(context.state.goalMinutes) MIN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.mint)
                    }
                    .padding(.vertical, 4)
                }

            } compactLeading: {
                Image(systemName: "iphone.slash")
                    .foregroundStyle(.mint)

            } compactTrailing: {
                Text(context.state.endDate, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 50)

            } minimal: {
                Image(systemName: "iphone.slash")
                    .foregroundStyle(.mint)
            }
            .keylineTint(.mint)
        }
    }

    private func progress(start: Date, end: Date) -> CGFloat {
        let total = end.timeIntervalSince(start)

        guard total > 0 else { return 0 }

        let elapsed = Date().timeIntervalSince(start)

        return CGFloat(min(max(elapsed / total, 0), 1))
    }

    private func minutesRemaining(until date: Date) -> Int {
        max(1, Int(ceil(date.timeIntervalSince(Date()) / 60)))
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
            return "The urge passes in about 90 seconds."
        case ..<0.6:
            return "This is the hard part. Stay with it."
        case ..<0.85:
            return "More than halfway — \(minutesLeft) min to go."
        default:
            return "Nearly there — \(minutesLeft) min left."
        }
    }
}

#Preview("PhoneFree Live Activity", as: .content, using: PhoneFreeWidgetAttributes(name: "PhoneFree")) {
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


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

                    Text("\(context.state.goalMinutes)-minute commitment")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
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

                            Text("Stay with the moment.")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
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
}

#Preview("PhoneFree Live Activity", as: .content, using: PhoneFreeWidgetAttributes(name: "PhoneFree")) {
    PhoneFreeWidgetLiveActivity()
} contentStates: {
    PhoneFreeWidgetAttributes.ContentState(
        startDate: .now,
        endDate: .now.addingTimeInterval(20 * 60),
        goalMinutes: 20
    )
}

import WidgetKit
import SwiftUI

private let appGroupID = "group.com.danielebuatti.phonefree"

struct PhoneFreeEntry: TimelineEntry {
    let date: Date
    let goalEnd: Date?
    let goalActive: Bool
    let goalsCompletedToday: Int
    let protectedMinutesToday: Int
    let lastCheckIn: Date?
}

struct PhoneFreeProvider: TimelineProvider {
    func placeholder(in context: Context) -> PhoneFreeEntry {
        PhoneFreeEntry(
            date: .now,
            goalEnd: Date().addingTimeInterval(600),
            goalActive: true,
            goalsCompletedToday: 2,
            protectedMinutesToday: 35,
            lastCheckIn: Date().addingTimeInterval(-3600)
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PhoneFreeEntry) -> Void
    ) {
        completion(loadEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PhoneFreeEntry>) -> Void
    ) {
        let entry = loadEntry()
        let refresh = Date().addingTimeInterval(15 * 60)

        completion(
            Timeline(entries: [entry], policy: .after(refresh))
        )
    }

    private func loadEntry() -> PhoneFreeEntry {
        let defaults = UserDefaults(suiteName: appGroupID)

        let active = defaults?.bool(
            forKey: "phoneFreeGoalActive"
        ) ?? false

        // Stored by the app as a `Date` (see ContentView.saveData), so read it
        // back as a `Date`. Reading it with `double(forKey:)` would always
        // return 0 and the widget would never show a countdown.
        let end = defaults?.object(
            forKey: "phoneFreeGoalEnd"
        ) as? Date

        var completedCount = 0
        var protectedSeconds: TimeInterval = 0

        if let data = defaults?.data(forKey: "phoneFreeHistory"),
           let events = try? JSONDecoder().decode(
               [SharedHistoryEvent].self,
               from: data
           ) {
            let today = events.filter {
                Calendar.current.isDateInToday($0.timestamp)
            }

            completedCount = today.filter {
                $0.kind == "goal_completed"
            }.count

            // Match the app's "time protected": completed AND ended goals.
            protectedSeconds = today
                .filter {
                    $0.kind == "goal_completed" ||
                    $0.kind == "goal_ended"
                }
                .reduce(0) {
                    $0 + ($1.duration ?? 0)
                }
        }

        return PhoneFreeEntry(
            date: .now,
            goalEnd: end,
            goalActive: active,
            goalsCompletedToday: completedCount,
            protectedMinutesToday: Int(protectedSeconds / 60),
            lastCheckIn: defaults?.object(
                forKey: "phoneFreeLastCheckIn"
            ) as? Date
        )
    }
}

private struct SharedHistoryEvent: Decodable {
    let timestamp: Date
    let kind: String
    let note: String?
    let duration: TimeInterval?
}

struct PhoneFreeWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: PhoneFreeEntry

    private let lavender = Color(
        red: 0.72, green: 0.66, blue: 1.0
    )

    private let mint = Color(
        red: 0.76, green: 0.91, blue: 0.75
    )

    private let background = Color(
        red: 0.075, green: 0.08, blue: 0.18
    )

    private var activeGoal: Bool {
        entry.goalActive &&
        (entry.goalEnd.map { $0 > .now } ?? false)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            accessoryInline
        default:
            mediumView
        }
    }

    // MARK: - Lock Screen (accessory) families
    //
    // These are the surfaces the user sees *before* they open anything, which
    // is the whole point: the number has to be in front of them at the moment
    // they reach for the phone. Unlike a Live Activity they never expire.

    /// The date the accessory families count from: a goal's end when one is
    /// running, otherwise the moment of the last confirmed phone use.
    private var accessoryDate: Date? {
        if activeGoal, let goalEnd = entry.goalEnd {
            return goalEnd
        }
        return entry.lastCheckIn
    }

    private var accessoryIsGoal: Bool {
        activeGoal && entry.goalEnd != nil
    }

    private var accessorySymbol: String {
        accessoryIsGoal ? "hourglass" : "iphone.slash"
    }

    private var accessoryCaption: String {
        accessoryIsGoal
            ? "TIME LEFT TO YOUR GOAL"
            : "SINCE YOU LAST USED YOUR PHONE"
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()

            if let date = accessoryDate {
                VStack(spacing: 0) {
                    Image(systemName: accessorySymbol)
                        .font(.system(size: 10, weight: .semibold))

                    Text(date, style: .timer)
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                }
            } else {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 20, weight: .semibold))
            }
        }
        .widgetURL(URL(string: "phonefree://goal")!)
        .containerBackground(Color.clear, for: .widget)
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(accessoryCaption)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let date = accessoryDate {
                Text(date, style: .timer)
                    .font(
                        .system(
                            size: 22,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text("Start a phone-free goal")
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "phonefree://goal")!)
        .containerBackground(Color.clear, for: .widget)
    }

    private var accessoryInline: some View {
        Group {
            if let date = accessoryDate {
                Label {
                    Text(date, style: .timer)
                } icon: {
                    Image(systemName: accessorySymbol)
                }
            } else {
                Label("Start a phone-free goal", systemImage: "iphone.slash")
            }
        }
    }

    // MARK: - Home Screen (system) families

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 7) {
            header

            Spacer(minLength: 0)

            if activeGoal, let goalEnd = entry.goalEnd {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME LEFT TO YOUR GOAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(goalEnd, style: .timer)
                        .font(
                            .system(
                                size: 34,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(mint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text("Keep going. You're making space.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            } else if let lastCheckIn = entry.lastCheckIn {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SINCE YOU LAST USED YOUR PHONE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(lastCheckIn, style: .timer)
                        .font(
                            .system(
                                size: 34,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(mint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text("Put it down and this keeps counting.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Choose a goal.")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("10 minutes away from your phone?")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Link(destination: URL(string: "phonefree://goal")!) {
                    HStack(spacing: 6) {
                        Image(systemName: activeGoal ? "hourglass" : "iphone.slash")
                        Text(activeGoal ? "View goal" : "Start a goal")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(background)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(
                        mint,
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                }

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(entry.goalsCompletedToday)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(lavender)

                    Text("DONE TODAY")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.3)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(width: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .containerBackground(background, for: .widget)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "moon.stars.fill")
                .foregroundStyle(lavender)

            Text("PHONEFREE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(lavender)

            Spacer()

            Text("THE PAUSE")
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(height: 18)
    }
}

struct PhoneFreeWidget: Widget {
    let kind = "PhoneFreeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: PhoneFreeProvider()
        ) { entry in
            PhoneFreeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("The Pause")
        .description(
            "Your away counter, on the Home Screen and the Lock Screen."
        )
        .supportedFamilies([
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

#Preview(as: .systemMedium) {
    PhoneFreeWidget()
} timeline: {
    PhoneFreeEntry(
        date: .now,
        goalEnd: Date().addingTimeInterval(600),
        goalActive: true,
        goalsCompletedToday: 2,
        protectedMinutesToday: 35,
        lastCheckIn: Date().addingTimeInterval(-3600)
    )

    PhoneFreeEntry(
        date: .now,
        goalEnd: nil,
        goalActive: false,
        goalsCompletedToday: 1,
        protectedMinutesToday: 20,
        lastCheckIn: Date().addingTimeInterval(-7200)
    )
}

#Preview(as: .accessoryRectangular) {
    PhoneFreeWidget()
} timeline: {
    PhoneFreeEntry(
        date: .now,
        goalEnd: nil,
        goalActive: false,
        goalsCompletedToday: 1,
        protectedMinutesToday: 20,
        lastCheckIn: Date().addingTimeInterval(-7200)
    )

    PhoneFreeEntry(
        date: .now,
        goalEnd: Date().addingTimeInterval(600),
        goalActive: true,
        goalsCompletedToday: 2,
        protectedMinutesToday: 35,
        lastCheckIn: Date().addingTimeInterval(-3600)
    )
}

#Preview(as: .accessoryCircular) {
    PhoneFreeWidget()
} timeline: {
    PhoneFreeEntry(
        date: .now,
        goalEnd: nil,
        goalActive: false,
        goalsCompletedToday: 1,
        protectedMinutesToday: 20,
        lastCheckIn: Date().addingTimeInterval(-7200)
    )
}

#Preview(as: .accessoryInline) {
    PhoneFreeWidget()
} timeline: {
    PhoneFreeEntry(
        date: .now,
        goalEnd: nil,
        goalActive: false,
        goalsCompletedToday: 1,
        protectedMinutesToday: 20,
        lastCheckIn: Date().addingTimeInterval(-7200)
    )
}

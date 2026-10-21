import WidgetKit
import SwiftUI

private let appGroupID = "group.com.danielebuatti.phonefree"

struct PhoneFreeEntry: TimelineEntry {
    let date: Date
    let goalEnd: Date?
    let goalActive: Bool
    let goalsCompletedToday: Int
    let protectedMinutesToday: Int
    /// Where the away counter counts up from. `nil` while the phone is in use,
    /// because then it is not counting.
    let lastCheckIn: Date?

    /// The next rung of the away counter's ladder, and the longest *finished*
    /// stretch ever. Named rather than implied — the whole app is about
    /// stretching the gap, so the gap needs something to stretch towards.
    let nextTargetSeconds: TimeInterval?
    let bestGapSeconds: TimeInterval

    /// The frozen stretch while the phone is in use inside the grace period.
    var pausedSeconds: TimeInterval? = nil

    /// The phone is still in use after the grace period: held at zero.
    var heldAtZero = false

    /// When the guard for this stretch runs out. `nil` unless a session is
    /// open. The accessory families need it to tell the *guard hold* (the away
    /// number frozen while the pickup is still free) from the state after it —
    /// where the number is red and counting, exactly as the Live Activity and
    /// the app draw it. Without it the accessory could only say "paused" over
    /// a counter the app had already turned red.
    var guardEndsAt: Date? = nil

    /// The stretch has already been recorded — the run is over even if a
    /// session is still nominally open (see `hasReset`). Red for the same
    /// reason `guardEndsAt` has passed.
    var stretchRecorded = false
}

struct PhoneFreeProvider: TimelineProvider {
    func placeholder(in context: Context) -> PhoneFreeEntry {
        PhoneFreeEntry(
            date: .now,
            goalEnd: Date().addingTimeInterval(600),
            goalActive: true,
            goalsCompletedToday: 2,
            protectedMinutesToday: 35,
            lastCheckIn: Date().addingTimeInterval(-3600),
            nextTargetSeconds: 2 * 3600,
            bestGapSeconds: 6 * 3600
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
        let now = Date()
        var entries = [loadEntry(at: now)]

        // While the phone is in use the counter changes state on a clock — at
        // the guard's end (hold turns red), at the reset, and when an
        // unclosed session is given up on — so those moments get entries of
        // their own instead of waiting for a refresh.
        let usage = PhoneFreeUsage.load()

        if usage.isUsing(at: now), let usingSince = usage.usingSince {
            let changes = [
                usage.guardEndsAt,
                usage.resetsAt,
                usingSince.addingTimeInterval(PhoneFreeUsage.abandonAfter),
            ]

            for date in changes.compactMap({ $0 }) where date > now {
                entries.append(loadEntry(at: date))
            }
        }

        completion(
            Timeline(
                entries: entries,
                policy: .after(now.addingTimeInterval(15 * 60))
            )
        )
    }

    private func loadEntry(at now: Date = Date()) -> PhoneFreeEntry {
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

        let usage = PhoneFreeUsage.load()
        let using = usage.isUsing(at: now)

        var completedCount = 0
        var protectedSeconds: TimeInterval = 0
        var bestGapSeconds: TimeInterval = 0

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

        // The longest *finished* stretch, from the same clock the app uses,
        // so the widget and the app never show two different records.
        bestGapSeconds = usage.bestEver

        // The stretch the number on screen belongs to — raw, because the
        // counter itself is raw. Where the Lock Screen counts up from: with a
        // session open that is the stretch that was frozen — when the phone
        // was picked up, less what was already earned — so locking the phone
        // carries the number on rather than freezing it while the app is
        // suspended.
        let awayAnchor = usage.awayAnchor(at: now)

        return PhoneFreeEntry(
            date: now,
            goalEnd: end,
            goalActive: active,
            goalsCompletedToday: completedCount,
            protectedMinutesToday: Int(protectedSeconds / 60),
            lastCheckIn: awayAnchor,
            // Milestones measure awake time, same as the app: sleep must not
            // climb the ladder. With no windows set this is the raw gap.
            nextTargetSeconds: PhoneFreeTargets.next(
                after: usage.awakeAwayInterval(at: now)
            ),
            bestGapSeconds: bestGapSeconds,
            // The frozen stretch stays on screen even after the run has ended,
            // so the number is never blanked to 0:00 while the phone is still
            // in the user's hand. `heldAtZero` still flags the reset for the
            // medium view's subtext. (`hasReset` implies an open session, so
            // it is always accompanied by `pausedSeconds`.)
            pausedSeconds: using ? usage.frozenInterval : nil,
            heldAtZero: usage.hasReset(at: now),
            // Only a live session has a guard to report. The accessory reads
            // these to decide hold vs red, the same way the Live Activity does.
            guardEndsAt: using ? usage.guardEndsAt : nil,
            stretchRecorded: using ? usage.stretchRecorded : false
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

    private let violet = Color(
        red: 0.62, green: 0.49, blue: 1.0
    )

    private let lime = Color(
        red: 0.76, green: 1.0, blue: 0.34
    )

    /// The warning red, identical to the Live Activity's `LAColor.coral`, so
    /// the Lock Screen, the Dynamic Island and the app all go red in the same
    /// shade at the same moment.
    private let coral = Color(
        red: 0.98, green: 0.49, blue: 0.60
    )

    private let background = Color(
        red: 0.043, green: 0.039, blue: 0.086
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

    /// `true` once the current stretch has passed its guard — the point the
    /// app and the Live Activity both turn red. Mirrors the Live Activity's
    /// `counterPhase`: no guard left, or the stretch already recorded, means
    /// red. Anything else with an open session is still a free hold.
    private var accessoryPastGuard: Bool {
        guard entry.pausedSeconds != nil else { return false }
        if entry.stretchRecorded { return true }
        guard let guardEnd = entry.guardEndsAt else { return true }
        return entry.date >= guardEnd
    }

    /// The date the accessory families count from: a goal's end when one is
    /// running. Otherwise, while the phone is in use, the counter is frozen
    /// (no live count-up) so the widget shows the held number; when not in use
    /// it counts up from the last check-in.
    private var accessoryDate: Date? {
        if activeGoal, let goalEnd = entry.goalEnd {
            return goalEnd
        }
        if entry.pausedSeconds != nil, !accessoryPastGuard {
            return nil
        }
        return entry.lastCheckIn
    }

    private var accessoryIsGoal: Bool {
        activeGoal && entry.goalEnd != nil
    }

    private var accessorySymbol: String {
        if accessoryIsGoal { return "hourglass" }
        if accessoryPastGuard { return "iphone" }
        return "iphone.slash"
    }

    /// The wording above the counter, shared by the Lock Screen and Home
    /// Screen families. While a session is open the number is paused, so the
    /// caption says so wherever it shows — it must never claim "since you
    /// last used your phone" over a counter that is paused *because* the
    /// phone is in the hand. Past the guard the number is running again, so
    /// the caption says what the number now means.
    private var counterCaption: String {
        if accessoryIsGoal { return "TIME LEFT TO YOUR GOAL" }
        if entry.pausedSeconds != nil {
            return accessoryPastGuard
                ? "ON YOUR PHONE"
                : "PAUSED — ON YOUR PHONE"
        }
        return "SINCE YOU LAST USED YOUR PHONE"
    }

    /// Red once the guard is spent — the same warning colour the app and the
    /// Live Activity use, so all three surfaces agree at a glance.
    private var accessoryTint: Color {
        accessoryPastGuard ? coral : .primary
    }

    /// The counter while it is not counting: always the frozen stretch, even
    /// once the run has ended. The number is never blanked while the phone is
    /// still in the user's hand.
    private var stillCounterText: String? {
        if let paused = entry.pausedSeconds {
            return Self.clock(paused)
        }
        if entry.heldAtZero {
            return Self.clock(0)
        }
        return nil
    }

    private static func clock(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds % 60)
            : String(format: "%d:%02d", minutes, seconds % 60)
    }

    /// "Next target 3h" — the rung the away counter is climbing towards.
    private var targetLine: String? {
        guard !accessoryIsGoal,
              let target = entry.nextTargetSeconds else { return nil }
        return "Next target \(PhoneFreeTargets.short(target))"
    }

    /// "Record 6h 03m" — the longest finished stretch, once there is one.
    private var recordLine: String? {
        guard entry.bestGapSeconds >= 60 else { return nil }
        return "Record \(PhoneFreeTargets.short(entry.bestGapSeconds))"
    }

    /// "Next target 3h · Record 6h 03m", with either half optional.
    private var targetSummary: String? {
        let parts = [targetLine, recordLine].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()

            if let date = accessoryDate {
                accessoryCounterStack(Text(date, style: .timer))
            } else if let still = stillCounterText {
                // Phone in use: the frozen stretch, as a plain string, so
                // the held number stays on screen instead of collapsing to
                // a bare icon (and never self-ticks while in the hand).
                accessoryCounterStack(Text(still))
            } else {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 20, weight: .semibold))
            }
        }
        .widgetURL(URL(string: "phonefree://goal")!)
        .containerBackground(Color.clear, for: .widget)
    }

    private func accessoryCounterStack(_ text: Text) -> some View {
        VStack(spacing: 0) {
            Image(systemName: accessorySymbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accessoryTint)

            text
                .font(
                    .system(
                        size: 13,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .monospacedDigit()
                .foregroundStyle(
                    accessoryPastGuard ? accessoryTint : .primary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.45)
        }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(counterCaption)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accessoryTint)
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
                    .foregroundStyle(
                        accessoryPastGuard ? accessoryTint : .primary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else if let still = stillCounterText {
                // Phone in use: the frozen stretch, as a plain string — the
                // held number must never be replaced by the start-goal CTA.
                Text(still)
                    .font(
                        .system(
                            size: 22,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        accessoryPastGuard ? accessoryTint : .secondary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text("Start a phone-free goal")
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            if let targetLine {
                Text(targetLine)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 1)
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
            } else if let still = stillCounterText {
                // Phone in use: the held number, not the start-goal CTA.
                Label(still, systemImage: accessorySymbol)
            } else {
                Label("Start a phone-free goal", systemImage: "iphone.slash")
            }
        }
        .foregroundStyle(accessoryPastGuard ? accessoryTint : .primary)
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
                        .foregroundStyle(violet)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text("Keep going. You're making space.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            } else if let still = stillCounterText {
                VStack(alignment: .leading, spacing: 4) {
                    Text(counterCaption)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(still)
                        .font(
                            .system(
                                size: 34,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(
                            accessoryPastGuard ? coral : violet.opacity(0.6)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text(
                        entry.heldAtZero
                            ? "Starts again when you put it down."
                            : "Put it down and this carries on."
                    )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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
                        .foregroundStyle(violet)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text(
                        targetSummary
                        ?? "Put it down and this keeps counting."
                    )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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
                        violet,
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                }

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(entry.goalsCompletedToday)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(lime)

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
                .foregroundStyle(violet)

            Text("PHONEFREE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(violet)

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
        .configurationDisplayName("PhoneFree")
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
        lastCheckIn: Date().addingTimeInterval(-3600),
        nextTargetSeconds: 90 * 60,
        bestGapSeconds: 6 * 3600
    )

    PhoneFreeEntry(
        date: .now,
        goalEnd: nil,
        goalActive: false,
        goalsCompletedToday: 1,
        protectedMinutesToday: 20,
        lastCheckIn: Date().addingTimeInterval(-7200),
        nextTargetSeconds: 3 * 3600,
        bestGapSeconds: 6 * 3600
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
        lastCheckIn: Date().addingTimeInterval(-7200),
        nextTargetSeconds: 3 * 3600,
        bestGapSeconds: 6 * 3600
    )

    PhoneFreeEntry(
        date: .now,
        goalEnd: Date().addingTimeInterval(600),
        goalActive: true,
        goalsCompletedToday: 2,
        protectedMinutesToday: 35,
        lastCheckIn: Date().addingTimeInterval(-3600),
        nextTargetSeconds: 90 * 60,
        bestGapSeconds: 6 * 3600
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
        lastCheckIn: Date().addingTimeInterval(-7200),
        nextTargetSeconds: 3 * 3600,
        bestGapSeconds: 6 * 3600
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
        lastCheckIn: Date().addingTimeInterval(-7200),
        nextTargetSeconds: 3 * 3600,
        bestGapSeconds: 6 * 3600
    )
}

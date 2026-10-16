
import SwiftUI
import WidgetKit
import Combine

private let appGroupID = "group.com.danielebuatti.phonefree"

private struct PhoneFreeEvent: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var kind: String
    var note: String?
    var duration: TimeInterval?
}

struct ContentView: View {
    @State private var events: [PhoneFreeEvent] = []
    @State private var selectedMinutes = 20
    @State private var goalStart: Date?
    @State private var goalEnd: Date?
    @State private var goalActive = false
    @State private var showingEndConfirmation = false

    private let goalOptions = [5, 10, 20, 30, 45]

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

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    header

                    timerSection

                    if goalActive {
                        activeGoalSection
                    } else {
                        goalPickerSection
                    }

                    dailyProgressSection

                    activitySection

                    footer
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadSavedData()
            finishExpiredGoalIfNeeded()
        }
        .onReceive(
            Timer.publish(
                every: 1,
                on: .main,
                in: .common
            ).autoconnect()
        ) { _ in
            finishExpiredGoalIfNeeded()
        }
        .confirmationDialog(
            "End your phone-free goal?",
            isPresented: $showingEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End goal early", role: .destructive) {
                endGoal()
            }

            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Your progress will still be recorded.")
        }
        .onOpenURL { url in
            guard url.scheme == "phonefree" else { return }

            if url.host == "goal" {
                // Open the app so you can deliberately begin a goal.
            } else if url.host == "end" {
                showingEndConfirmation = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("PHONEFREE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(accent)

                Text("Make space.")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Image(systemName: "iphone.slash")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.06))
                .clipShape(Circle())
        }
    }

    // MARK: - Main timer

    private var timerSection: some View {
        VStack(spacing: 20) {
            Text(goalActive ? "YOUR PHONE-FREE TIME" : "TIME FOR YOURSELF")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(muted)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                let start = goalStart ?? now
                let end = goalEnd ?? now

                let totalDuration = max(
                    Double(selectedMinutes * 60),
                    1
                )

                let elapsed = goalActive
                    ? min(max(now.timeIntervalSince(start), 0), totalDuration)
                    : 0

                let remaining = goalActive
                    ? max(end.timeIntervalSince(now), 0)
                    : totalDuration

                let progress = goalActive
                    ? min(max(elapsed / totalDuration, 0), 1)
                    : 0

                ZStack {
                    Circle()
                        .stroke(
                            .white.opacity(0.07),
                            lineWidth: 13
                        )

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    accent.opacity(0.45),
                                    accent,
                                    Color(red: 0.39, green: 0.77, blue: 0.87)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(
                                lineWidth: 13,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .fill(.white.opacity(0.025))
                        .padding(17)

                    VStack(spacing: 10) {
                        Image(
                            systemName: goalActive
                                ? "leaf.fill"
                                : "moon.stars.fill"
                        )
                        .font(.system(size: 23))
                        .foregroundStyle(accent)

                        if goalActive {
                            Text(formatTime(remaining))
                                .font(
                                    .system(
                                        size: 38,
                                        weight: .light,
                                        design: .rounded
                                    )
                                )
                                .monospacedDigit()
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .foregroundStyle(.white)
                        } else {
                            Text("\(selectedMinutes):00")
                                .font(
                                    .system(
                                        size: 38,
                                        weight: .light,
                                        design: .rounded
                                    )
                                )
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }

                        Text(goalActive ? "REMAINING" : "YOUR NEXT PAUSE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.8)
                            .foregroundStyle(muted)

                        if goalActive {
                            Text("\(Int(elapsed / 60)) min away")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(accent)
                        } else {
                            Text("Put your phone down")
                                .font(.system(size: 13))
                                .foregroundStyle(muted)
                        }
                    }
                    .padding(20)
                }
                .frame(width: 260, height: 260)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    goalActive
                        ? "\(Int(elapsed / 60)) minutes phone-free, \(Int(remaining / 60)) minutes remaining"
                        : "\(selectedMinutes) minute phone-free goal"
                )
            }
            .frame(maxWidth: .infinity)

            if goalActive {
                VStack(spacing: 6) {
                    Text("You're making space.")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white)

                    Text("You don't need to check anything right now.")
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 6) {
                    Text("Give yourself a little space.")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white)

                    Text("Choose a time. Put your phone down. See how it feels.")
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Goal picker

    private var goalPickerSection: some View {
        VStack(spacing: 16) {
            Text("HOW LONG WOULD YOU LIKE?")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(muted)

            HStack(spacing: 9) {
                ForEach(goalOptions, id: \.self) { minutes in
                    Button {
                        selectedMinutes = minutes
                    } label: {
                        VStack(spacing: 5) {
                            Text("\(minutes)")
                                .font(.system(size: 18, weight: .semibold))

                            Text("MIN")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundStyle(
                            selectedMinutes == minutes
                                ? background
                                : .white
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(
                            selectedMinutes == minutes
                                ? accent
                                : .white.opacity(0.055)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(
                                    selectedMinutes == minutes
                                        ? accent
                                        : .white.opacity(0.08),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                startGoal()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "iphone.slash")

                    Text("Put my phone down")
                        .font(.system(size: 16, weight: .semibold))

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(background)
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 17))
            }
            .buttonStyle(.plain)

            Text("Start your goal, then lock your screen.")
                .font(.system(size: 12))
                .foregroundStyle(muted)
        }
    }

    // MARK: - Active goal

    private var activeGoalSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(selectedMinutes)-minute commitment")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)

                    Text(
                        "Started \(goalStart ?? .now, style: .time)"
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
                }

                Spacer()

                Image(systemName: "lock.fill")
                    .foregroundStyle(muted)
            }
            .padding(16)
            .background(.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                showingEndConfirmation = true
            } label: {
                Text("End goal early")
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

    // MARK: - Daily progress

    private var dailyProgressSection: some View {
        HStack(spacing: 12) {
            statCard(
                value: "\(completedGoalsToday)",
                label: "GOALS COMPLETED",
                symbol: "checkmark.circle"
            )

            statCard(
                value: formattedProtectedTime,
                label: "TIME PROTECTED",
                symbol: "clock"
            )
        }
    }

    private func statCard(
        value: String,
        label: String,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(accent)

            Text(value)
                .font(.system(size: 25, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }

    // MARK: - Activity history

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your progress")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text("TODAY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(muted)
            }

            let todayEvents = events
                .filter {
                    Calendar.current.isDateInToday($0.timestamp)
                }
                .sorted {
                    $0.timestamp > $1.timestamp
                }

            if todayEvents.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 19))
                        .foregroundStyle(accent)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("A fresh start")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)

                        Text("Your phone-free moments will appear here.")
                            .font(.system(size: 12))
                            .foregroundStyle(muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(17)
                .background(.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(todayEvents.prefix(8)) { event in
                    HStack(spacing: 12) {
                        Image(
                            systemName: event.kind == "goal_completed"
                                ? "checkmark.circle.fill"
                                : event.kind == "goal_ended"
                                    ? "pause.circle"
                                    : "leaf"
                        )
                        .font(.system(size: 18))
                        .foregroundStyle(
                            event.kind == "goal_completed"
                                ? accent
                                : muted
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(eventTitle(event))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)

                            Text(event.timestamp, style: .time)
                                .font(.system(size: 12))
                                .foregroundStyle(muted)
                        }

                        Spacer()

                        if let duration = event.duration {
                            Text("\(Int(duration / 60)) min")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(accent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var footer: some View {
        Text("Small pauses. More life beyond the screen.")
            .font(.system(size: 12))
            .foregroundStyle(muted.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.top, 2)
    }

    // MARK: - Goal actions

    private func startGoal() {
        guard !goalActive else { return }

        let now = Date()
        let end = now.addingTimeInterval(
            TimeInterval(selectedMinutes * 60)
        )

        goalStart = now
        goalEnd = end
        goalActive = true

        events.append(
            PhoneFreeEvent(
                timestamp: now,
                kind: "goal_started",
                note: "\(selectedMinutes)-minute goal",
                duration: nil
            )
        )

        saveData()

        PhoneFreeLiveActivityManager.shared.start(
            minutes: selectedMinutes,
            start: now,
            end: end
        )
    }

    private func endGoal() {
        guard goalActive else { return }

        let now = Date()
        let elapsed = max(
            0,
            now.timeIntervalSince(goalStart ?? now)
        )

        events.append(
            PhoneFreeEvent(
                timestamp: now,
                kind: "goal_ended",
                note: "Ended early",
                duration: elapsed
            )
        )

        goalActive = false
        goalStart = nil
        goalEnd = nil

        saveData()

        PhoneFreeLiveActivityManager.shared.end()
    }

    private func finishExpiredGoalIfNeeded() {
        guard
            goalActive,
            let end = goalEnd,
            Date() >= end
        else {
            return
        }

        let start = goalStart ?? end.addingTimeInterval(
            -TimeInterval(selectedMinutes * 60)
        )

        events.append(
            PhoneFreeEvent(
                timestamp: end,
                kind: "goal_completed",
                note: "\(selectedMinutes)-minute goal",
                duration: end.timeIntervalSince(start)
            )
        )

        goalActive = false
        goalStart = nil
        goalEnd = nil

        saveData()

        PhoneFreeLiveActivityManager.shared.end()
    }

    // MARK: - Persistence

    private func loadSavedData() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return
        }

        if let data = defaults.data(forKey: "phoneFreeHistory"),
           let savedEvents = try? JSONDecoder().decode(
                [PhoneFreeEvent].self,
                from: data
           ) {
            events = savedEvents
        }

        goalActive = defaults.bool(forKey: "phoneFreeGoalActive")

        if let timestamp = defaults.object(
            forKey: "phoneFreeGoalStart"
        ) as? Date {
            goalStart = timestamp
        }

        if let timestamp = defaults.object(
            forKey: "phoneFreeGoalEnd"
        ) as? Date {
            goalEnd = timestamp
        }

        if let start = goalStart,
           let end = goalEnd,
           end > start {
            let seconds = end.timeIntervalSince(start)
            selectedMinutes = max(1, Int(seconds / 60))
        }

        if !goalActive {
            goalStart = nil
            goalEnd = nil
        } else if let start = goalStart, let end = goalEnd, end > .now {
            PhoneFreeLiveActivityManager.shared.restoreIfNeeded(
                minutes: selectedMinutes,
                start: start,
                end: end
            )
        }
    }

    private func saveData() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return
        }

        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: "phoneFreeHistory")
        }

        defaults.set(goalActive, forKey: "phoneFreeGoalActive")

        if let goalStart {
            defaults.set(goalStart, forKey: "phoneFreeGoalStart")
        } else {
            defaults.removeObject(forKey: "phoneFreeGoalStart")
        }

        if let goalEnd {
            defaults.set(goalEnd, forKey: "phoneFreeGoalEnd")
        } else {
            defaults.removeObject(forKey: "phoneFreeGoalEnd")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Display helpers

    private var completedGoalsToday: Int {
        events.filter {
            $0.kind == "goal_completed" &&
            Calendar.current.isDateInToday($0.timestamp)
        }.count
    }

    private var protectedSecondsToday: TimeInterval {
        events
            .filter {
                ($0.kind == "goal_completed" || $0.kind == "goal_ended") &&
                Calendar.current.isDateInToday($0.timestamp)
            }
            .reduce(0) {
                $0 + ($1.duration ?? 0)
            }
    }

    private var formattedProtectedTime: String {
        let minutes = Int(protectedSecondsToday / 60)

        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }

        return "\(minutes)m"
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

        return String(
            format: "%02d:%02d",
            minutes,
            remainder
        )
    }

    private func eventTitle(_ event: PhoneFreeEvent) -> String {
        switch event.kind {
        case "goal_completed":
            return "Phone-free goal completed"
        case "goal_ended":
            return "Goal ended early"
        case "goal_started":
            return "Phone-free goal started"
        default:
            return event.note ?? "Phone-free moment"
        }
    }
}

#Preview {
    ContentView()
}

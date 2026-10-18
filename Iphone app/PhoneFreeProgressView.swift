//
//  PhoneFreeProgressView.swift
//  Iphone app
//
//  Everything the app has noticed, kept out of the way of the home screen.
//
//  A note on streaks: streak mechanics can turn into a compulsion, which is
//  the last thing this app should create for the people it is for. So the run
//  is shown as a fact ("4-day run"), never as a warning, and breaking it costs
//  nothing and is never mentioned again.
//

import Charts
import SwiftUI

struct PhoneFreeProgressView: View {
    @Environment(PhoneFreeStore.self) private var store

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header

                runCard

                statGrid

                chartSection

                if store.mostEnjoyed != nil || store.hardest != nil {
                    insightsSection
                }

                historySection
            }
            .padding(.horizontal, PhoneFreeTheme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(PhoneFreeTheme.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PROGRESS")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(PhoneFreeTheme.accent)

            Text("What you've protected")
                .scaledFont(26, weight: .semibold, relativeTo: .title)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Run

    private var runCard: some View {
        PhoneFreeCard(padding: 18) {
            PhoneFreeAdaptiveStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(PhoneFreeTheme.accent.opacity(0.15))

                    Text("\(store.goalRunDays)")
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .foregroundStyle(PhoneFreeTheme.accent)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        store.goalRunDays == 1
                            ? "1-day run"
                            : "\(store.goalRunDays)-day run"
                    )
                    .scaledFont(18, weight: .semibold, relativeTo: .title3)
                    .foregroundStyle(.white)

                    Text(runSubtitle)
                        .font(.footnote)
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var runSubtitle: String {
        if store.goalRunDays == 0 {
            return "Finish a goal today and a run starts. Nothing is lost."
        }

        return "Days in a row you finished at least one goal."
    }

    // MARK: - Stats

    private var statGrid: some View {
        VStack(spacing: 12) {
            PhoneFreeAdaptiveStack(spacing: 12) {
                statCard(
                    value: PhoneFreeFormat.duration(
                        store.protectedSecondsToday
                    ),
                    label: "PROTECTED TODAY",
                    symbol: "clock"
                )

                statCard(
                    value: "\(store.pickupsToday)",
                    label: "TIMES YOU OPENED PHONEFREE",
                    symbol: "hand.raised"
                )
            }

            PhoneFreeAdaptiveStack(spacing: 12) {
                statCard(
                    value: PhoneFreeFormat.clock(store.bestGapTodayDisplay),
                    label: "LONGEST PAUSE TODAY",
                    symbol: "hourglass"
                )

                statCard(
                    value: "\(store.completedGoalsToday)",
                    label: "GOALS FINISHED",
                    symbol: "checkmark.seal.fill",
                    tint: PhoneFreeTheme.reward
                )
            }

            freeTimeCard

            PhoneFreeCard {
                HStack(spacing: 14) {
                    Image(systemName: "trophy")
                        .font(.callout)
                        .foregroundStyle(PhoneFreeTheme.accent)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            "Longest pause ever: "
                            + PhoneFreeFormat.clock(store.longestGapEver)
                        )
                        .scaledFont(14, weight: .medium, relativeTo: .subheadline)
                        .foregroundStyle(.white)

                        Text(
                            "Measured between one pickup and the next, "
                            + "including the one running now."
                        )
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }

            PhoneFreeCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(PhoneFreeTheme.muted)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("“Times you opened PhoneFree”")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(
                            "iOS does not let an app see your real unlocks, so "
                            + "this counts the times you opened PhoneFree "
                            + "itself. That is a stand-in, not the whole "
                            + "picture: counting every pickup needs Apple's "
                            + "Screen Time permission, which this app cannot "
                            + "use yet."
                        )
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func statCard(
        value: String,
        label: String,
        symbol: String,
        tint: Color = PhoneFreeTheme.accent
    ) -> some View {
        PhoneFreeCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.callout)
                    .foregroundStyle(tint)

                Text(value)
                    .scaledFont(24, weight: .medium, design: .rounded, relativeTo: .title2)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(label)
                    .scaledFont(9, weight: .bold, relativeTo: .caption2)
                    .tracking(0.9)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The reward loop, where people look back at what they've done. Banked
    /// free time is something gained, so it is only ever the reward colour —
    /// never framed as a shortfall.
    private var freeTimeCard: some View {
        PhoneFreeCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "bolt.fill")
                    .scaledFont(18, relativeTo: .title3)
                    .foregroundStyle(PhoneFreeTheme.reward)

                VStack(alignment: .leading, spacing: 3) {
                    Text(PhoneFreeFormat.duration(store.surplusSeconds))
                        .scaledFont(
                            22,
                            weight: .semibold,
                            design: .rounded,
                            relativeTo: .title2
                        )
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .accessibilityLabel(
                            "\(PhoneFreeFormat.spoken(store.surplusSeconds)) "
                            + "of free phone time banked"
                        )

                    Text("FREE TIME BANKED")
                        .scaledFont(9, weight: .bold, relativeTo: .caption2)
                        .tracking(0.9)
                        .foregroundStyle(PhoneFreeTheme.reward)

                    Text(
                        store.surplusSeconds > 0
                            ? "Earned by finishing goals. It pays for phone "
                                + "time past your grace period, so your streak "
                                + "survives."
                            : "Finish a goal and you'll bank free phone time "
                                + "here. It protects your streak while you use "
                                + "your phone."
                    )
                    .font(.caption)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("LAST 7 DAYS")

            let data = store.dailyProtected(days: 7)
            let hasData = data.contains { $0.seconds > 0 }

            PhoneFreeCard(padding: 18) {
                if hasData {
                    Chart(data, id: \.date) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Minutes", day.seconds / 60)
                        )
                        .foregroundStyle(PhoneFreeTheme.accent)
                        .cornerRadius(5)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let minutes = value.as(Double.self) {
                                    Text("\(Int(minutes))m")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(
                                format: .dateTime.weekday(.narrow)
                            )
                        }
                    }
                    .frame(height: 160)
                } else {
                    VStack(spacing: 6) {
                        Text("No protected time yet")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)

                        Text("Finish a goal and the bar for today will appear.")
                            .font(.caption)
                            .foregroundStyle(PhoneFreeTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 160)
                }
            }
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("WHAT WORKS FOR YOU")

            VStack(spacing: 10) {
                if let best = store.mostEnjoyed {
                    insightRow(
                        symbol: best.symbol,
                        title: "You enjoy \(best.name.lowercased())",
                        detail: "It'll come up in your suggestions again."
                    )
                }

                if let hard = store.hardest {
                    insightRow(
                        symbol: "flame",
                        title: "\(hard.name) felt hard",
                        detail: "Try a shorter version, or something gentler."
                    )
                }
            }
        }
    }

    private func insightRow(
        symbol: String,
        title: String,
        detail: String
    ) -> some View {
        PhoneFreeCard {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.callout)
                    .foregroundStyle(PhoneFreeTheme.accent)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .scaledFont(14, weight: .medium, relativeTo: .subheadline)
                        .foregroundStyle(.white)

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneFreeSectionLabel("TODAY")

            let history = store.todayHistory

            if history.isEmpty {
                PhoneFreeCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sun.max")
                            .scaledFont(18, relativeTo: .title3)
                            .foregroundStyle(PhoneFreeTheme.accent)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("A fresh start")
                                .scaledFont(14, weight: .medium, relativeTo: .subheadline)
                                .foregroundStyle(.white)

                            Text(
                                "Your phone-free moments will appear here."
                            )
                            .font(.caption)
                            .foregroundStyle(PhoneFreeTheme.muted)
                        }

                        Spacer(minLength: 0)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(history) { event in
                        historyRow(event)
                    }
                }
            }
        }
    }

    private func historyRow(_ event: PhoneFreeEvent) -> some View {
        let completed = event.kind == PhoneFreeEventKind.goalCompleted

        return PhoneFreeCard {
            HStack(spacing: 14) {
                Image(
                    systemName: completed
                        ? "checkmark.circle.fill"
                        : "pause.circle"
                )
                .scaledFont(18, relativeTo: .title3)
                .foregroundStyle(
                    completed ? PhoneFreeTheme.reward : PhoneFreeTheme.muted
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title(for: event))
                        .scaledFont(14, weight: .medium, relativeTo: .subheadline)
                        .foregroundStyle(.white)

                    Text(event.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                }

                Spacer(minLength: 0)

                if let duration = event.duration {
                    Text(PhoneFreeFormat.duration(duration))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(
                            completed
                                ? PhoneFreeTheme.reward
                                : PhoneFreeTheme.muted
                        )
                }
            }
        }
    }

    private func title(for event: PhoneFreeEvent) -> String {
        switch event.kind {
        case PhoneFreeEventKind.goalCompleted:
            return "Goal completed"
        case PhoneFreeEventKind.goalEnded:
            return "Ended early"
        case PhoneFreeEventKind.goalStarted:
            return "Goal started"
        default:
            return event.note ?? "Phone-free moment"
        }
    }
}

#Preview {
    PhoneFreeProgressView()
        .environment(PhoneFreeStore())
        .preferredColorScheme(.dark)
}

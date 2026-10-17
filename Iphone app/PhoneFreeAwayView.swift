//
//  PhoneFreeAwayView.swift
//  Iphone app
//
//  The home screen. It answers one question first — "how long since I last
//  used my phone?" — and then offers exactly one thing to do about it.
//
//  Design rules that come out of building this for people with OCD and ADHD:
//   * one primary button on screen at a time, never two competing ones;
//   * every control is labelled in words, not implied by an arrow;
//   * nothing is hidden behind an unlabelled icon;
//   * the optional step is clearly marked optional.
//

import SwiftUI

struct PhoneFreeAwayView: View {
    @Environment(PhoneFreeStore.self) private var store

    @State private var showingPlanBuilder = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                header

                if store.showsResetCountdown() {
                    usageBanner
                }

                if store.goalActive {
                    activeGoalHero
                    goalDetail
                } else {
                    awayHero
                    startSection
                }

                todaySummary
            }
            .padding(.horizontal, PhoneFreeTheme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(PhoneFreeTheme.background)
        .sheet(isPresented: $showingPlanBuilder) {
            ActivityPlanBuilder(
                plan: Binding(
                    get: { store.plan },
                    set: { store.plan = $0 }
                ),
                suggestions: store.suggestedActivities,
                hasReflections: !store.reflections.isEmpty,
                onSave: { store.save() }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PHONEFREE")
                    .font(.caption.weight(.bold))
                    .tracking(3)
                    .foregroundStyle(PhoneFreeTheme.accent)

                Text("Make space.")
                    .scaledFont(26, weight: .semibold, relativeTo: .title)
                    .foregroundStyle(.white)
            }

            Spacer()
        }
    }

    // MARK: - The number that matters (no goal running)

    private var awayHero: some View {
        VStack(spacing: 14) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 16) {
                    Text(
                        heroCaption(at: context.date)
                    )
                    .font(.caption2.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .multilineTextAlignment(.center)

                    Text(PhoneFreeFormat.clock(store.awayInterval(at: context.date)))
                        .scaledFont(64, weight: .light, design: .rounded, relativeTo: .largeTitle)
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(.white)

                    Rectangle()
                        .fill(PhoneFreeTheme.cardBorder)
                        .frame(height: 1)
                        .padding(.horizontal, 4)

                    gapTargetBlock(at: context.date, compact: false)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 26)
        .background(PhoneFreeTheme.card)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PhoneFreeTheme.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PhoneFreeTheme.cornerRadius,
                style: .continuous
            )
            .stroke(PhoneFreeTheme.cardBorder, lineWidth: 1)
        }
    }

    // MARK: - The number that matters (goal running)

    private var activeGoalHero: some View {
        VStack(spacing: 16) {
            Text("TIME LEFT IN YOUR PHONE-FREE GOAL")
                .font(.caption2.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(PhoneFreeTheme.muted)
                .multilineTextAlignment(.center)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.07), lineWidth: 12)

                        Circle()
                            .trim(
                                from: 0,
                                to: store.goalProgress(at: context.date)
                            )
                            .stroke(
                                PhoneFreeTheme.accent,
                                style: StrokeStyle(
                                    lineWidth: 12,
                                    lineCap: .round
                                )
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 6) {
                            Text(
                                PhoneFreeFormat.clock(
                                    store.goalRemaining(at: context.date)
                                )
                            )
                            .scaledFont(40, weight: .light, design: .rounded, relativeTo: .largeTitle)
                            .monospacedDigit()
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .foregroundStyle(.white)

                            Text("REMAINING")
                                .scaledFont(10, weight: .bold, relativeTo: .caption2)
                                .tracking(1.8)
                                .foregroundStyle(PhoneFreeTheme.muted)
                        }
                    }
                    .frame(width: 210, height: 210)

                    Text(
                        "Away from your phone for "
                        + PhoneFreeFormat.clock(
                            store.awayInterval(at: context.date)
                        )
                    )
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PhoneFreeTheme.accent)

                    gapTargetBlock(at: context.date, compact: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 26)
        .background(PhoneFreeTheme.card)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PhoneFreeTheme.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PhoneFreeTheme.cornerRadius,
                style: .continuous
            )
            .stroke(PhoneFreeTheme.cardBorder, lineWidth: 1)
        }
    }

    // MARK: - Target block
    //
    // The away counter is more useful when it is climbing towards something.
    // This names the next rung of the ladder in words, shows how close it is,
    // and — when the run happening right now has beaten every finished one —
    // says so. Never framed as something to lose.

    @ViewBuilder
    private func gapTargetBlock(at date: Date, compact: Bool) -> some View {
        VStack(spacing: 9) {
            if let target = store.nextGapTarget(at: date) {
                PhoneFreeAdaptiveStack(
                    spacing: 0,
                    horizontalAlignment: .center,
                    verticalAlignment: .firstTextBaseline
                ) {
                    Text("NEXT TARGET")
                        .scaledFont(10, weight: .bold, relativeTo: .caption2)
                        .tracking(1.4)
                        .foregroundStyle(PhoneFreeTheme.muted)

                    Spacer(minLength: 8)

                    Text(PhoneFreeTargets.short(target))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                if !compact {
                    progressBar(store.gapTargetProgress(at: date))
                }

                VStack(spacing: 4) {
                    if let remaining = store.gapTimeToTarget(at: date) {
                        Text("\(PhoneFreeTargets.short(remaining)) to go")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PhoneFreeTheme.muted)
                    }

                    recordLine
                }
            } else {
                Text(
                    "You have climbed the whole ladder. Anything from here "
                    + "is a bonus."
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(PhoneFreeTheme.accent)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func progressBar(
        _ progress: Double,
        label: String = "Progress towards your next target"
    ) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(PhoneFreeTheme.accent)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    @ViewBuilder
    private var recordLine: some View {
        if store.isNewLongestGap {
            HStack(spacing: 5) {
                Image(systemName: "star.fill")

                Text("New record — your longest stretch yet.")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(PhoneFreeTheme.accent)
        } else if store.hasRecord {
            Text(
                "Your record "
                + PhoneFreeFormat.clock(store.bestCompletedGapEver)
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(PhoneFreeTheme.muted)
        }
    }

    // MARK: - Goal detail

    private var goalDetail: some View {
        VStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let current = store.currentActivity(at: context.date) {
                    PhoneFreeCard {
                        PhoneFreeAdaptiveStack(spacing: 14) {
                            Image(systemName: current.activity.symbol)
                                .scaledFont(18, relativeTo: .title3)
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                .foregroundStyle(PhoneFreeTheme.background)
                                .frame(width: 40, height: 40)
                                .background(PhoneFreeTheme.accent)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text("DOING RIGHT NOW")
                                    .scaledFont(10, weight: .bold, relativeTo: .caption2)
                                    .tracking(1.2)
                                    .foregroundStyle(
                                        PhoneFreeTheme.muted
                                    )

                                Text(current.activity.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            Text(
                                "\(max(1, Int(ceil(current.end.timeIntervalSince(context.date) / 60)))) min"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PhoneFreeTheme.accent)
                        }
                    }
                }
            }

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your goal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(
                        "\(store.runningGoalMinutes) minutes, started "
                        + (store.goalStart ?? Date()).formatted(
                            date: .omitted,
                            time: .shortened
                        )
                        + ". You don't need to check anything right now."
                    )
                    .font(.footnote)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            PhoneFreeSecondaryButton(
                title: "End this goal early",
                symbol: "lock.open"
            ) {
                store.requestEndGoal()
            }
        }
    }

    // MARK: - Start a goal

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            PhoneFreeSectionLabel("START PHONE-FREE TIME")

            VStack(alignment: .leading, spacing: 10) {
                Text("How long?")
                    .scaledFont(14, weight: .medium, relativeTo: .subheadline)
                    .foregroundStyle(.white)

                minuteChips
            }

            planStep

            VStack(spacing: 10) {
                PhoneFreePrimaryButton(
                    title: store.plan.isEmpty
                        ? "Start \(store.selectedMinutes) min phone-free"
                        : "Start \(store.planTotalMinutes) min plan",
                    symbol: "iphone.slash"
                ) {
                    store.startGoal()
                }

                Text("Then lock your screen. The countdown keeps going on "
                     + "your Lock Screen.")
                    .font(.caption)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(PhoneFreeTheme.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PhoneFreeTheme.cornerRadius,
                style: .continuous
            )
        )
    }

    private var minuteChips: some View {
        // One row normally; wraps onto a second row at the larger
        // accessibility text sizes so the numbers stay readable.
        let columns = dynamicTypeSize.isAccessibilitySize
            ? 3
            : store.goalOptions.count

        return LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 9),
                count: columns
            ),
            spacing: 9
        ) {
            ForEach(store.goalOptions, id: \.self) { minutes in
                let selected = !store.plan.isEmpty
                    ? false
                    : store.selectedMinutes == minutes

                Button {
                    store.selectedMinutes = minutes
                    store.save()
                } label: {
                    VStack(spacing: 4) {
                        Text("\(minutes)")
                            .scaledFont(18, weight: .semibold, relativeTo: .title3)

                        Text("MIN")
                            .scaledFont(9, weight: .bold, relativeTo: .caption2)
                            .tracking(1)
                    }
                    .foregroundStyle(
                        selected ? PhoneFreeTheme.background : .white
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .frame(minHeight: 62)
                    .background(
                        selected
                            ? PhoneFreeTheme.accent
                            : Color.white.opacity(0.05)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                        .stroke(
                            selected
                                ? PhoneFreeTheme.accent
                                : PhoneFreeTheme.cardBorder,
                            lineWidth: 1
                        )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(minutes) minutes")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .opacity(store.plan.isEmpty ? 1 : 0.4)
        .disabled(!store.plan.isEmpty)
    }

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhoneFreeAdaptiveStack(spacing: 6) {
                Text("Something to do instead")
                    .scaledFont(14, weight: .medium, relativeTo: .subheadline)
                    .foregroundStyle(.white)

                Text("optional")
                    .scaledFont(10, weight: .bold, relativeTo: .caption2)
                    .tracking(0.8)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
            }

            if store.plan.isEmpty {
                PhoneFreeSecondaryButton(
                    title: "Add an activity",
                    symbol: "plus"
                ) {
                    showingPlanBuilder = true
                }

                Text("A plan sets the goal's length and shows you what to do "
                     + "while your phone is away, one step at a time.")
                    .font(.caption)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.plan) { planned in
                        if let activity = planned.activity {
                            HStack(spacing: 12) {
                                Image(systemName: activity.symbol)
                                    .scaledFont(14, relativeTo: .subheadline)
                                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                    .foregroundStyle(
                                        PhoneFreeTheme.background
                                    )
                                    .frame(width: 32, height: 32)
                                    .background(PhoneFreeTheme.accent)
                                    .clipShape(Circle())

                                Text(activity.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)

                                Spacer()

                                Text("\(planned.minutes) min")
                                    .scaledFont(14, weight: .semibold, relativeTo: .subheadline)
                                    .foregroundStyle(PhoneFreeTheme.accent)
                            }
                        }
                    }
                }

                PhoneFreeAdaptiveStack(spacing: 10) {
                    PhoneFreeSecondaryButton(
                        title: "Edit plan",
                        symbol: "slider.horizontal.3"
                    ) {
                        showingPlanBuilder = true
                    }

                    PhoneFreeSecondaryButton(title: "Remove") {
                        store.clearPlan()
                    }
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? nil : 110
                    )
                }
            }
        }
    }

    // MARK: - Today

    private var todaySummary: some View {
        // Things gained, not things given in to. A count of pick-ups on the
        // home screen becomes one more number to check and feel bad about.
        PhoneFreeAdaptiveStack(spacing: 12, verticalAlignment: .top) {
            statCard(
                value: PhoneFreeFormat.clock(store.bestGapToday),
                label: "BEST STRETCH TODAY",
                symbol: "star"
            )

            statCard(
                value: "\(store.completedGoalsToday)",
                label: "GOALS FINISHED TODAY",
                symbol: "checkmark.circle"
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func statCard(
        value: String,
        label: String,
        symbol: String
    ) -> some View {
        PhoneFreeCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.callout)
                    .foregroundStyle(PhoneFreeTheme.accent)

                Text(value)
                    .scaledFont(26, weight: .medium, design: .rounded, relativeTo: .title)
                    .foregroundStyle(.white)

                Text(label)
                    .scaledFont(9, weight: .bold, relativeTo: .caption2)
                    .tracking(0.9)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func heroCaption(at date: Date) -> String {
        guard store.showsResetCountdown(at: date) else {
            return "SINCE YOU LAST USED YOUR PHONE"
        }

        return store.usage.hasReset(at: date)
            ? "STARTS WHEN YOU PUT YOUR PHONE DOWN"
            : "PAUSED — YOU'RE ON YOUR PHONE"
    }

    // MARK: - Using the phone
    //
    // While the app is open the phone is in use, so the counter is frozen and
    // a grace period runs. This says so plainly, counts it down, and offers
    // the one thing that saves the streak.

    private var usageBanner: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let usage = store.usage
            let reset = usage.hasReset(at: context.date)
            let left = usage.resetsAt.map {
                max(0, $0.timeIntervalSince(context.date))
            } ?? 0

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(
                            systemName: reset
                                ? "arrow.counterclockwise"
                                : "hourglass.bottomhalf.filled"
                        )
                        .font(.subheadline)
                        .foregroundStyle(PhoneFreeTheme.accent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                reset
                                    ? "Your timer started again"
                                    : "Timer resets in "
                                        + PhoneFreeUsage.shortSeconds(left)
                            )
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                            Text(
                                reset
                                    ? "That's okay. It counts up again from the "
                                        + "moment you put your phone down."
                                    : "You're on your phone, so the counter is "
                                        + "paused. Put it down now and "
                                        + (usage.frozenInterval >= 60
                                            ? "your "
                                                + PhoneFreeFormat.clock(
                                                    usage.frozenInterval
                                                )
                                                + " carries on."
                                            : "it carries on.")
                            )
                            .font(.caption)
                            .foregroundStyle(PhoneFreeTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    if !reset {
                        progressBar(
                            left / max(usage.resetAfter, 1),
                            label: "Time left before your timer resets"
                        )

                        // Secondary on purpose: "start a goal" further down
                        // stays the one filled button on this screen.
                        PhoneFreeSecondaryButton(
                            title: "I'll put it down",
                            tint: PhoneFreeTheme.accent
                        ) {
                            store.putItDown()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    PhoneFreeAwayView()
        .environment(PhoneFreeStore())
        .preferredColorScheme(.dark)
}

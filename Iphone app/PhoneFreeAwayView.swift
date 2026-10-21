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
import UIKit

struct PhoneFreeAwayView: View {
    @Environment(PhoneFreeStore.self) private var store
    @Environment(\.openURL) private var openURL

    @State private var showingPlanBuilder = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                header

                if let award = store.surplusAward {
                    surplusAwardBanner(award)
                }

                if let room = store.sharedSession, !room.isOver {
                    awaySessionCard(room)
                }

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

                surplusCard

                todaySummary
            }
            .padding(.horizontal, PhoneFreeTheme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
            .animation(
                reduceMotion ? nil : .snappy,
                value: store.surplusAward
            )
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

    /// A live shared session, so the people in it never have to go hunting
    /// for the room. Tapping opens the full sheet; the card itself stays
    /// quiet — a roommate, not an alarm.
    private func awaySessionCard(_ room: SharedSessionState) -> some View {
        Button {
            store.showingSharedSessionSheet = true
        } label: {
            PhoneFreeCard {
                HStack(spacing: 12) {
                    Image(systemName: room.mode == .sharedFate ? "link" : "person.2.fill")
                        .font(.callout)
                        .foregroundStyle(PhoneFreeTheme.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("With \(otherNames(in: room))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(room.mode == .sharedFate
                             ? "Shared fate — one of you picks up, it ends for both"
                             : "Own counters — your phone, your rules")
                            .font(.caption)
                            .foregroundStyle(PhoneFreeTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Text(PhoneFreeFormat.duration(room.duration(at: Date())))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(PhoneFreeTheme.reward)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shared session with \(otherNames(in: room)). Tap to open.")
    }

    private func otherNames(in room: SharedSessionState) -> String {
        let others = room.participants
            .filter { $0.id != store.participantID }
            .map(\.name)
        return others.isEmpty ? "yourself" : others.joined(separator: ", ")
    }

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
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let away = store.counterInterval(at: context.date)
            let progress = store.gapTargetProgress(at: context.date)
            let tint: Color = away < 0
                ? PhoneFreeTheme.caution
                : (store.isShielded(at: context.date)
                    ? PhoneFreeTheme.reward
                    : PhoneFreeTheme.accent)

            VStack(spacing: 16) {
                Text(heroCaption(at: context.date))
                    .font(.caption2.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .multilineTextAlignment(.center)

                if store.progressStyle == .ring {
                    PhoneFreeRingMeter(progress: progress, tint: tint) {
                        awayNumber(away)
                    }
                } else {
                    awayNumber(away)

                    if store.progressStyle == .bar {
                        PhoneFreeBarMeter(progress: progress, tint: tint)
                            .accessibilityLabel(
                                "Progress towards your next target"
                            )
                    }
                }

                Rectangle()
                    .fill(PhoneFreeTheme.cardBorder)
                    .frame(height: 1)
                    .padding(.horizontal, 4)

                gapTargetBlock(at: context.date)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 26)
            .background {
                if store.progressStyle == .water {
                    PhoneFreeWaterFill(progress: progress, tint: tint)
                }
            }
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
    }

    private func awayNumber(_ away: TimeInterval) -> some View {
        Text(PhoneFreeFormat.clock(away))
            .scaledFont(
                64,
                weight: .light,
                design: .rounded,
                relativeTo: .largeTitle
            )
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(away < 0 ? PhoneFreeTheme.caution : .white)
            .accessibilityLabel(PhoneFreeFormat.spoken(away))
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
                let remaining = store.goalRemaining(at: context.date)
                let progress = store.goalProgress(at: context.date)

                VStack(spacing: 18) {
                    if store.progressStyle == .ring {
                        PhoneFreeRingMeter(progress: progress) {
                            goalNumber(remaining)
                        }
                    } else {
                        goalNumber(remaining)

                        if store.progressStyle == .bar {
                            PhoneFreeBarMeter(progress: progress)
                                .accessibilityLabel("Goal progress")
                        }
                    }

                    Text(
                        store.usage.isUsing(at: context.date)
                            ? "Paused while you're on your phone. Lock it "
                                + "and the goal does the rest."
                            : "Away from your phone for "
                                + PhoneFreeFormat.clock(
                                    store.awayInterval(at: context.date)
                                )
                    )
                    .multilineTextAlignment(.center)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PhoneFreeTheme.accent)

                    gapTargetBlock(at: context.date)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 26)
                .background {
                    if store.progressStyle == .water {
                        PhoneFreeWaterFill(progress: progress)
                    }
                }
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
        }
    }

    private func goalNumber(_ remaining: TimeInterval) -> some View {
        VStack(spacing: 6) {
            Text(PhoneFreeFormat.clock(remaining))
                .scaledFont(
                    40,
                    weight: .light,
                    design: .rounded,
                    relativeTo: .largeTitle
                )
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(.white)
                .accessibilityLabel(
                    "\(PhoneFreeFormat.spoken(remaining)) remaining"
                )

            Text("REMAINING")
                .scaledFont(10, weight: .bold, relativeTo: .caption2)
                .tracking(1.8)
                .foregroundStyle(PhoneFreeTheme.muted)
        }
    }

    // MARK: - Surplus
    //
    // The reward loop, made visible: finish a goal, bank free phone time, and
    // watch that time protect the streak while the phone is in use.

    private func surplusAwardBanner(_ seconds: TimeInterval) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.headline)
                .foregroundStyle(PhoneFreeTheme.reward)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    "You earned " + PhoneFreeFormat.duration(seconds)
                    + " of free phone time"
                )
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

                Text("It's banked, and it protects your streak.")
                    .font(.caption)
                    .foregroundStyle(PhoneFreeTheme.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PhoneFreeTheme.reward.opacity(0.16))
        .clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PhoneFreeTheme.reward.opacity(0.5), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var surplusCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let banked = store.surplusSeconds
            let remaining = store.surplusRemaining(at: context.date)
            let shielded = store.isShielded(at: context.date)

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    PhoneFreeAdaptiveStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(PhoneFreeTheme.reward.opacity(0.16))

                            Image(systemName: "bolt.fill")
                                .font(.headline)
                                .foregroundStyle(PhoneFreeTheme.reward)
                        }
                        .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                shielded
                                    ? "Free time is protecting your streak"
                                    : "Free phone time"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                            Text(
                                PhoneFreeFormat.duration(
                                    shielded ? remaining : banked
                                )
                            )
                            .font(
                                .system(
                                    .title2,
                                    design: .rounded,
                                    weight: .bold
                                )
                            )
                            .monospacedDigit()
                            .foregroundStyle(PhoneFreeTheme.reward)
                            .accessibilityLabel(
                                "\(PhoneFreeFormat.spoken(shielded ? remaining : banked)) of free phone time"
                            )
                        }

                        Spacer(minLength: 0)
                    }

                    progressBar(
                        banked / max(store.surplusCap, 1),
                        tint: PhoneFreeTheme.reward,
                        label: "Free phone time banked"
                    )

                    Text(
                        surplusExplanation(shielded: shielded, banked: banked)
                    )
                    .font(.caption)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func surplusExplanation(
        shielded: Bool,
        banked: TimeInterval
    ) -> String {
        if shielded {
            return "You're using banked time instead of your streak. When it "
                + "runs out, your counter starts again — so lock up to save "
                + "what's left."
        }

        if banked <= 0 {
            return "Finish a phone-free goal and you'll bank free phone time "
                + "here. Use your phone and it pays for the time, so your "
                + "streak survives."
        }

        return "Earned by finishing goals. Use your phone and this pays for "
            + "it, so your counter keeps its place."
    }

    // MARK: - Target block
    //
    // The away counter is more useful when it is climbing towards something.
    // This names the next rung of the ladder in words, shows how close it is,
    // and — when the run happening right now has beaten every finished one —
    // says so. Never framed as something to lose.
    //
    // The progress *picture* lives in the hero above, in whichever style the
    // user chose, so this stays words only.

    @ViewBuilder
    private func gapTargetBlock(at date: Date) -> some View {
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
        tint: Color = PhoneFreeTheme.accent,
        label: String = "Progress towards your next target"
    ) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
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

    /// The goal length the primary button will start — named here so the
    /// reward hint can promise the same number the goal will bank.
    private var goalMinutes: Int {
        store.plan.isEmpty ? store.selectedMinutes : store.planTotalMinutes
    }

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

                Label(
                    "Finish it and you bank \(goalMinutes) min of free "
                    + "phone time.",
                    systemImage: "bolt.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(PhoneFreeTheme.reward)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

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
                    store.play(.selection)
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
                symbol: "checkmark.seal.fill",
                tint: PhoneFreeTheme.reward
            )
        }
        .fixedSize(horizontal: false, vertical: true)
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

    /// While PhoneFree is open the phone is in use, so the caption never
    /// claims the number is "since you last used" it.
    private func heroCaption(at date: Date) -> String {
        guard store.isUsingPhone(at: date) else {
            return "SINCE YOU LAST USED YOUR PHONE"
        }

        if !store.isPastGuard(at: date) {
            return "PUT IT DOWN TO KEEP YOUR STRETCH"
        }

        return store.usage.hasReset(at: date)
            ? "PUT IT DOWN TO START THE NEXT ONE"
            : "FREE TIME — YOUR STRETCH IS SAFE"
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
            let guardLeft = usage.guardEndsAt.map {
                max(0, $0.timeIntervalSince(context.date))
            } ?? 0

            let shielded = store.isShielded(at: context.date)
            // The guard comes first: the counter holds, nothing is lost, and
            // there is still time to put the phone down.
            let guarding = guardLeft > 0 && !reset

            // The bar covers the whole shield — the guard still available plus
            // whatever free time is banked — so it shrinks at an honest, even
            // rate. The guard is a per-day budget, so this can be shorter than
            // the configured maximum when some of it has been spent.
            let fullGrace = max(usage.guardSeconds + usage.surplus, 1)
            let tint = shielded
                ? PhoneFreeTheme.reward
                : PhoneFreeTheme.accent

            PhoneFreeCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(
                            systemName: reset
                                ? "arrow.counterclockwise"
                                : (shielded
                                    ? "bolt.fill"
                                    : "hourglass.bottomhalf.filled")
                        )
                        .font(.subheadline)
                        .foregroundStyle(tint)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                reset
                                    ? "Your streak restarts when you put it "
                                        + "down"
                                    : (guarding
                                        ? PhoneFreeUsage.shortSeconds(guardLeft)
                                            + " to put it down"
                                        : (shielded
                                            ? "Free time is protecting your "
                                                + "streak"
                                            : "On your phone"))
                            )
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                            Text(
                                bannerDetail(
                                    frozen: usage.frozenInterval,
                                    reset: reset,
                                    guarding: guarding,
                                    shieldLeft: left
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(PhoneFreeTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    if guarding {
                        progressBar(
                            guardLeft / max(usage.guardSeconds, 1),
                            tint: tint,
                            label: "Time left to put it down"
                        )
                    } else if !reset {
                        progressBar(
                            left / fullGrace,
                            tint: tint,
                            label: shielded
                                ? "Free time left before your timer resets"
                                : "Time left before your timer resets"
                        )
                    }

                    // No button: the only way to put the phone down is to
                    // lock it, and a button here would pretend otherwise.
                    Label(
                        "Press the side button to lock your phone",
                        systemImage: "lock"
                    )
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(tint)

                    if store.atRiskWithoutReminders {
                        remindersOffNotice
                    }
                }
            }
        }
    }

    /// The last place PhoneFree can speak to the user before they leave.
    ///
    /// Every warning this app gives about a stretch at risk travels by
    /// notification, and a notification cannot reach somebody who is in another
    /// app if permission is off. So the one moment the app is certain to have
    /// their attention is also the moment it should admit the reminders are
    /// not going anywhere.
    private var remindersOffNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(PhoneFreeTheme.cardBorder)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bell.slash")
                    .font(.subheadline)
                    .foregroundStyle(PhoneFreeTheme.accent)

                Text(
                    store.reminderPermission == .refused
                        ? "Notifications are off for PhoneFree, so nothing "
                            + "can warn you while you're in another app."
                        : "Reminders haven't been allowed yet, so nothing "
                            + "can warn you while you're in another app."
                )
                .font(.caption)
                .foregroundStyle(PhoneFreeTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            PhoneFreeSecondaryButton(
                title: store.reminderPermission == .refused
                    ? "Open notification settings"
                    : "Allow reminders",
                symbol: "bell",
                tint: PhoneFreeTheme.accent,
                action: fixReminders
            )
        }
    }

    /// Mirrors Settings. iOS only ever puts the permission prompt up once, so
    /// a refusal has to be undone in Settings, while a question never asked can
    /// still be asked here — where the reason for it is on screen.
    private func fixReminders() {
        if store.reminderPermission == .refused {
            if let url = URL(
                string: UIApplication.openNotificationSettingsURLString
            ) {
                openURL(url)
            }
            return
        }

        Task {
            _ = await PhoneFreeWindowScheduler.shared.requestAuthorization()
            await store.refreshReminderPermission()
        }
    }

    private func bannerDetail(
        frozen: TimeInterval,
        reset: Bool,
        guarding: Bool,
        shieldLeft: TimeInterval
    ) -> String {
        if guarding {
            return "The counter is holding at "
                + PhoneFreeFormat.clock(frozen)
                + ". Put the phone down and it carries on; stay on it and it "
                + "starts counting the time in your hand in red."
        }

        if reset {
            return "That's okay. The stretch above counts towards your "
                + "record, and locking your phone now starts the next one."
        }

        return "You're spending banked free time, not your streak. "
            + "\(PhoneFreeUsage.shortSeconds(shieldLeft)) left before it "
            + "resets — lock it to save the rest."
    }
}

#Preview {
    PhoneFreeAwayView()
        .environment(PhoneFreeStore())
        .preferredColorScheme(.dark)
}

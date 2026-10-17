//
//  PhoneFreeActivityViews.swift
//  Iphone app
//
//  Two supporting screens for activity mode:
//   - ActivityPlanBuilder: choose activities and how long to give each one.
//   - ReflectionSheet: afterwards, say how each one felt.
//

import SwiftUI

// MARK: - Shared look

private let gateBackground = Color(red: 0.055, green: 0.065, blue: 0.12)
private let gateAccent = Color(red: 0.65, green: 0.91, blue: 0.79)
private let gateMuted = Color(red: 0.62, green: 0.65, blue: 0.74)

// MARK: - Plan builder

struct ActivityPlanBuilder: View {
    @Binding var plan: [PlannedActivity]

    /// Activities the advisor thinks this user will like, shown first.
    var suggestions: [PhoneFreeActivity] = []

    /// Whether the user has reflected before, which changes the pitch above
    /// the suggestions.
    var hasReflections: Bool = false

    /// Called after any change so the plan is written to disk straight away.
    var onSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var planTotal: Int {
        plan.reduce(0) { $0 + $1.minutes }
    }

    /// Suggested activities that are not in the plan yet, so the list never
    /// offers something the user already has.
    private var remainingSuggestions: [PhoneFreeActivity] {
        suggestions.filter { suggestion in
            !plan.contains { $0.activityID == suggestion.id }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    if plan.isEmpty {
                        emptyHint
                    } else {
                        planSection
                    }

                    if !remainingSuggestions.isEmpty {
                        suggestionsSection
                    }

                    librarySection
                }
                .padding(20)
            }
            .background(gateBackground.ignoresSafeArea())
            .navigationTitle("Add something to do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !plan.isEmpty {
                        Button("Clear") {
                            plan = []
                            onSave()
                        }
                        .foregroundStyle(gateMuted)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                    .foregroundStyle(gateAccent)
                    .fontWeight(.semibold)
                }
            }
            .preferredColorScheme(.dark)
        }
        .onDisappear { onSave() }
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("YOUR PLAN")

            Text(
                "Add one or two things to do. How long you give them sets the "
                + "length of your phone-free goal, and they'll appear on your "
                + "Lock Screen while you're away."
            )
            .font(.footnote)
            .foregroundStyle(gateMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - The plan

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("YOUR PLAN")

                Text("Tap a number to change how long each one lasts.")
                    .font(.caption)
                    .foregroundStyle(gateMuted)
            }

            ForEach(plan) { planned in
                if let activity = planned.activity {
                    plannedCard(activity: activity, planned: planned)
                }
            }

            PhoneFreeAdaptiveStack(spacing: 4) {
                Text("TOTAL PHONE-FREE TIME")
                    .scaledFont(10, weight: .bold, relativeTo: .caption2)
                    .tracking(1.4)
                    .foregroundStyle(gateMuted)

                Spacer()

                Text("\(planTotal) min")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(gateAccent)
            }
            .padding(.top, 2)
        }
    }

    private func plannedCard(
        activity: PhoneFreeActivity,
        planned: PlannedActivity
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: activity.symbol)
                    .font(.subheadline)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(gateBackground)
                    .frame(width: 34, height: 34)
                    .background(gateAccent)
                    .clipShape(Circle())

                Text(activity.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    plan.removeAll { $0.id == planned.id }
                    onSave()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(gateMuted)
                        .scaledFont(18, relativeTo: .title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(activity.name)")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("HOW LONG?")
                    .scaledFont(10, weight: .bold, relativeTo: .caption2)
                    .tracking(1.2)
                    .foregroundStyle(gateMuted)

                // One row normally; two columns at the larger accessibility
                // text sizes so "45 min" never gets squeezed.
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 8),
                        count: dynamicTypeSize.isAccessibilitySize
                            ? 2
                            : minuteOptions(for: planned).count
                    ),
                    spacing: 8
                ) {
                    ForEach(minuteOptions(for: planned), id: \.self) { minutes in
                        let selected = planned.minutes == minutes

                        Button {
                            setMinutes(minutes, for: planned.id)
                        } label: {
                            Text("\(minutes) min")
                                .scaledFont(14, weight: .semibold, relativeTo: .subheadline)
                                .foregroundStyle(
                                    selected ? gateBackground : .white
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .frame(minHeight: 42)
                                .background(
                                    selected ? gateAccent : .white.opacity(0.06)
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 11,
                                        style: .continuous
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(minutes) minutes")
                        .accessibilityAddTraits(
                            selected ? .isSelected : []
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    /// The activity's own suggestions, plus whatever it is currently set to —
    /// so the selected chip is always visible even if the value came from
    /// somewhere else.
    private func minuteOptions(for planned: PlannedActivity) -> [Int] {
        guard let activity = planned.activity else {
            return [planned.minutes]
        }

        var options = activity.suggestedMinutes

        if !options.contains(planned.minutes) {
            options.append(planned.minutes)
            options.sort()
        }

        return options
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("SUGGESTED FOR YOU")

            Text(
                hasReflections
                    ? "Based on what you've told us about your time."
                    : "A place to start."
            )
            .font(.caption)
            .foregroundStyle(gateMuted)

            ForEach(remainingSuggestions) { activity in
                activityRow(activity)
            }
        }
    }

    // MARK: - Full library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ALL ACTIVITIES")

            ForEach(PhoneFreeActivityLibrary.all) { activity in
                activityRow(activity)
            }
        }
    }

    private func activityRow(_ activity: PhoneFreeActivity) -> some View {
        PhoneFreeAdaptiveStack(spacing: 12) {
            Image(systemName: activity.symbol)
                .font(.subheadline)
                .foregroundStyle(gateAccent)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Text(activity.tagline)
                    .font(.caption)
                    .foregroundStyle(gateMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                plan.append(
                    PlannedActivity(
                        activityID: activity.id,
                        minutes: activity.defaultMinutes
                    )
                )
                onSave()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")

                    Text("\(activity.defaultMinutes) min")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(gateBackground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 36)
                .background(gateAccent)
                .clipShape(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "Add \(activity.name), \(activity.defaultMinutes) minutes"
            )
        }
        .padding(14)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .tracking(1.8)
            .foregroundStyle(gateMuted)
    }

    private func setMinutes(_ minutes: Int, for id: UUID) {
        guard let index = plan.firstIndex(where: { $0.id == id }) else {
            return
        }

        plan[index].minutes = minutes
        onSave()
    }
}

// MARK: - Reflection

struct ReflectionSheet: View {
    let plan: [PlannedActivity]

    let onSave: ([PhoneFreeReflection]) -> Void
    let onSkip: () -> Void

    @State private var enjoymentScores: [UUID: Int] = [:]
    @State private var difficultyScores: [UUID: Int] = [:]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How did that go?")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(
                            "A few taps help the app suggest better things next time."
                        )
                        .font(.footnote)
                        .foregroundStyle(gateMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(plan) { planned in
                        if let activity = planned.activity {
                            reflectionCard(
                                activity: activity,
                                planned: planned
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(gateBackground.ignoresSafeArea())
            .navigationTitle("Your time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        onSkip()
                    }
                    .foregroundStyle(gateMuted)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(buildReflections())
                    }
                    .foregroundStyle(gateAccent)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func reflectionCard(
        activity: PhoneFreeActivity,
        planned: PlannedActivity
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: activity.symbol)
                    .font(.callout)
                    .foregroundStyle(gateAccent)

                Text("\(activity.name) · \(planned.minutes) min")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()
            }

            ratingRow(
                title: "Did you enjoy it?",
                symbol: "heart",
                value: enjoymentBinding(planned.id),
                lowLabel: "Not really",
                highLabel: "Loved it"
            )

            ratingRow(
                title: "How hard was it?",
                symbol: "flame",
                value: difficultyBinding(planned.id),
                lowLabel: "Easy",
                highLabel: "Very hard"
            )
        }
        .padding(16)
        .background(.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func ratingRow(
        title: String,
        symbol: String,
        value: Binding<Int>,
        lowLabel: String,
        highLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption)
                    .foregroundStyle(gateAccent)

                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { score in
                    let selected = score <= value.wrappedValue

                    Button {
                        value.wrappedValue = score
                    } label: {
                        Text("\(score)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                selected ? gateBackground : gateMuted
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .frame(minHeight: 32)
                            .background(
                                selected
                                    ? gateAccent
                                    : .white.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .scaledFont(10, relativeTo: .caption2)
            .foregroundStyle(gateMuted)
        }
    }

    private func enjoymentBinding(_ id: UUID) -> Binding<Int> {
        Binding(
            get: { enjoymentScores[id] ?? 3 },
            set: { enjoymentScores[id] = $0 }
        )
    }

    private func difficultyBinding(_ id: UUID) -> Binding<Int> {
        Binding(
            get: { difficultyScores[id] ?? 3 },
            set: { difficultyScores[id] = $0 }
        )
    }

    private func buildReflections() -> [PhoneFreeReflection] {
        let now = Date()

        return plan.compactMap { planned in
            guard PhoneFreeActivityLibrary.activity(
                id: planned.activityID
            ) != nil else {
                return nil
            }

            return PhoneFreeReflection(
                activityID: planned.activityID,
                timestamp: now,
                minutes: planned.minutes,
                enjoyment: enjoymentScores[planned.id] ?? 3,
                difficulty: difficultyScores[planned.id] ?? 3,
                note: nil
            )
        }
    }
}

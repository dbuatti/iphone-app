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

    @Environment(\.dismiss) private var dismiss

    private var planTotal: Int {
        plan.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if !plan.isEmpty {
                        planSection
                    }

                    librarySection
                }
                .padding(20)
            }
            .background(gateBackground.ignoresSafeArea())
            .navigationTitle("Plan your time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !plan.isEmpty {
                        Button("Clear") {
                            plan = []
                        }
                        .foregroundStyle(gateMuted)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(gateAccent)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("YOUR PLAN")

            ForEach(plan) { planned in
                if let activity = planned.activity {
                    HStack(spacing: 12) {
                        Image(systemName: activity.symbol)
                            .font(.system(size: 15))
                            .foregroundStyle(gateAccent)
                            .frame(width: 24)

                        Text(activity.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)

                        Spacer()

                        Menu {
                            ForEach(
                                activity.suggestedMinutes,
                                id: \.self
                            ) { minutes in
                                Button("\(minutes) min") {
                                    setMinutes(minutes, for: planned.id)
                                }
                            }
                        } label: {
                            Text("\(planned.minutes) min")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(gateAccent)
                        }

                        Button {
                            plan.removeAll { $0.id == planned.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(gateMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            HStack {
                Text("TOTAL PHONE-FREE TIME")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(gateMuted)

                Spacer()

                Text("\(planTotal) min")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(gateAccent)
            }
            .padding(.top, 2)
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ADD AN ACTIVITY")

            ForEach(PhoneFreeActivityLibrary.all) { activity in
                Button {
                    plan.append(
                        PlannedActivity(
                            activityID: activity.id,
                            minutes: activity.defaultMinutes
                        )
                    )
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: activity.symbol)
                            .font(.system(size: 15))
                            .foregroundStyle(gateAccent)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(activity.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)

                            Text(activity.tagline)
                                .font(.system(size: 12))
                                .foregroundStyle(gateMuted)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        Image(systemName: "plus.circle")
                            .font(.system(size: 17))
                            .foregroundStyle(gateAccent)
                    }
                    .padding(14)
                    .background(.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.8)
            .foregroundStyle(gateMuted)
    }

    private func setMinutes(_ minutes: Int, for id: UUID) {
        guard let index = plan.firstIndex(where: { $0.id == id }) else {
            return
        }

        plan[index].minutes = minutes
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
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(
                            "A few taps help the app suggest better things next time."
                        )
                        .font(.system(size: 13))
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
                    .font(.system(size: 16))
                    .foregroundStyle(gateAccent)

                Text("\(activity.name) · \(planned.minutes) min")
                    .font(.system(size: 15, weight: .semibold))
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
                    .font(.system(size: 12))
                    .foregroundStyle(gateAccent)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { score in
                    let selected = score <= value.wrappedValue

                    Button {
                        value.wrappedValue = score
                    } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                selected
                                    ? gateAccent
                                    : .white.opacity(0.07)
                            )
                            .frame(height: 32)
                            .overlay {
                                Text("\(score)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(
                                        selected ? gateBackground : gateMuted
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.system(size: 10))
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
                enjoyment: enjoymentScores[planned.id] ?? 3,
                difficulty: difficultyScores[planned.id] ?? 3,
                note: nil
            )
        }
    }
}

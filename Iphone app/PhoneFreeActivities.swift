//
//  PhoneFreeActivities.swift
//  Iphone app
//
//  The "activity mode": instead of only taking time away from the phone, the
//  app helps the user fill that time with something wholesome. Users build a
//  small plan (e.g. 10 min reading, then 10 min yoga), the plan drives the
//  length of the phone-free goal, and the Live Activity shows whatever they
//  are meant to be doing right now.
//
//  Afterwards they reflect on how each activity felt. Those reflections feed
//  the advisor, which suggests activities in a comfortable "stretch" zone.
//

import Foundation

// MARK: - Activity

/// A wholesome, screen-free thing you can do with protected time.
struct PhoneFreeActivity: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let tagline: String

    /// Baseline challenge: 1 (gentle) ... 3 (demanding).
    let challenge: Int

    /// Durations that make sense for this activity, in minutes.
    let suggestedMinutes: [Int]

    var defaultMinutes: Int {
        suggestedMinutes[suggestedMinutes.count / 2]
    }
}

enum PhoneFreeActivityLibrary {
    static let all: [PhoneFreeActivity] = [
        PhoneFreeActivity(
            id: "reading",
            name: "Read",
            symbol: "book.fill",
            tagline: "A few pages of something you chose.",
            challenge: 1,
            suggestedMinutes: [10, 20, 30]
        ),
        PhoneFreeActivity(
            id: "walk",
            name: "Walk",
            symbol: "figure.walk",
            tagline: "Outside, no destination needed.",
            challenge: 1,
            suggestedMinutes: [10, 20, 30]
        ),
        PhoneFreeActivity(
            id: "stretch",
            name: "Stretch",
            symbol: "figure.flexibility",
            tagline: "Loosen up whatever is tight.",
            challenge: 1,
            suggestedMinutes: [5, 10, 15]
        ),
        PhoneFreeActivity(
            id: "rest",
            name: "Rest your eyes",
            symbol: "moon.zzz.fill",
            tagline: "Lie down. Do nothing at all.",
            challenge: 1,
            suggestedMinutes: [10, 20, 30]
        ),
        PhoneFreeActivity(
            id: "music",
            name: "Listen",
            symbol: "music.note",
            tagline: "A whole album, start to finish.",
            challenge: 1,
            suggestedMinutes: [10, 20, 30]
        ),
        PhoneFreeActivity(
            id: "tidy",
            name: "Reset a space",
            symbol: "sparkles",
            tagline: "One drawer, one surface, one shelf.",
            challenge: 1,
            suggestedMinutes: [10, 15, 20]
        ),
        PhoneFreeActivity(
            id: "breathe",
            name: "Breathe",
            symbol: "wind",
            tagline: "Slow, deliberate breaths.",
            challenge: 2,
            suggestedMinutes: [3, 5, 10]
        ),
        PhoneFreeActivity(
            id: "journal",
            name: "Journal",
            symbol: "square.and.pencil",
            tagline: "Three lines is enough.",
            challenge: 2,
            suggestedMinutes: [5, 10, 20]
        ),
        PhoneFreeActivity(
            id: "meditate",
            name: "Meditate",
            symbol: "figure.mind.and.body",
            tagline: "Sit. Notice. Come back.",
            challenge: 2,
            suggestedMinutes: [5, 10, 20]
        ),
        PhoneFreeActivity(
            id: "yoga",
            name: "Yoga",
            symbol: "figure.yoga",
            tagline: "Move slowly and deliberately.",
            challenge: 2,
            suggestedMinutes: [10, 20, 30]
        ),
        PhoneFreeActivity(
            id: "draw",
            name: "Draw",
            symbol: "pencil.and.outline",
            tagline: "Something in front of you.",
            challenge: 2,
            suggestedMinutes: [10, 20, 30]
        )
    ]

    static func activity(id: String) -> PhoneFreeActivity? {
        all.first { $0.id == id }
    }
}

// MARK: - Plan

/// One entry in a phone-free plan: an activity and how long to give it.
struct PlannedActivity: Codable, Identifiable, Hashable {
    var id = UUID()
    var activityID: String
    var minutes: Int

    var activity: PhoneFreeActivity? {
        PhoneFreeActivityLibrary.activity(id: activityID)
    }
}

// MARK: - Reflection

/// How one planned activity actually felt, asked straight afterwards.
struct PhoneFreeReflection: Codable, Identifiable, Hashable {
    var id = UUID()
    var activityID: String
    var timestamp: Date

    /// 1 (not at all) ... 5 (a lot)
    var enjoyment: Int

    /// 1 (easy) ... 5 (very hard)
    var difficulty: Int

    var note: String?

    var activity: PhoneFreeActivity? {
        PhoneFreeActivityLibrary.activity(id: activityID)
    }
}

// MARK: - Advisor

/// Suggests what to do next based on what the user has reported.
///
/// The aim is a gentle stretch: activities that were enjoyable, and activities
/// that sat around "moderate" difficulty rather than at either extreme. Things
/// that have never been tried get a nudge so the user keeps exploring.
enum PhoneFreeAdvisor {
    /// The difficulty we aim for — hard enough to absorb attention, not so hard
    /// that it becomes another thing to fail at.
    private static let targetDifficulty = 3.0

    static func suggestions(
        from reflections: [PhoneFreeReflection],
        limit: Int = 3
    ) -> [PhoneFreeActivity] {
        let scored = PhoneFreeActivityLibrary.all.map { activity
            -> (activity: PhoneFreeActivity, score: Double) in

            let matching = reflections.filter { $0.activityID == activity.id }

            guard !matching.isEmpty else {
                // Never tried: keep it in the running for variety.
                return (activity, 1.5)
            }

            let averageDifficulty =
                Double(matching.map(\.difficulty).reduce(0, +))
                / Double(matching.count)

            let averageEnjoyment =
                Double(matching.map(\.enjoyment).reduce(0, +))
                / Double(matching.count)

            let challengeFit = 2.0 - abs(averageDifficulty - targetDifficulty)
            let enjoymentFit = (averageEnjoyment - 3.0) * 0.4

            return (activity, challengeFit + enjoymentFit)
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.activity)
    }

    /// The activity the user has enjoyed most, if they have told us enough.
    static func mostEnjoyed(
        from reflections: [PhoneFreeReflection]
    ) -> PhoneFreeActivity? {
        let grouped = Dictionary(grouping: reflections, by: \.activityID)

        let best = grouped
            .map { id, items -> (String, Double) in
                let average =
                    Double(items.map(\.enjoyment).reduce(0, +))
                    / Double(items.count)

                return (id, average)
            }
            .filter { $0.1 >= 3.5 }
            .max { $0.1 < $1.1 }

        guard let best else { return nil }

        return PhoneFreeActivityLibrary.activity(id: best.0)
    }

    /// The activity the user found hardest, if any stood out.
    static func hardest(
        from reflections: [PhoneFreeReflection]
    ) -> PhoneFreeActivity? {
        let grouped = Dictionary(grouping: reflections, by: \.activityID)

        let hardest = grouped
            .map { id, items -> (String, Double) in
                let average =
                    Double(items.map(\.difficulty).reduce(0, +))
                    / Double(items.count)

                return (id, average)
            }
            .filter { $0.1 >= 4.0 }
            .max { $0.1 < $1.1 }

        guard let hardest else { return nil }

        return PhoneFreeActivityLibrary.activity(id: hardest.0)
    }
}

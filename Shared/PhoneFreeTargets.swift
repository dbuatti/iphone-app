//
//  PhoneFreeTargets.swift
//  Shared
//
//  Compiled into BOTH the "Iphone app" target and the "PhoneFreeWidgetExtension"
//  target, so the app and the Lock Screen always agree on what the "next
//  target" is.
//
//  The whole point of the app is to stretch the time between phone uses. A
//  number going up is nice, but a number going up *towards something* is what
//  actually changes behaviour, so the away counter climbs a ladder of
//  milestones. The next one is always named, never implied.
//

import Foundation

// `nonisolated` opts out of the app target's default MainActor isolation so the
// widget extension and the app compute targets identically.
nonisolated enum PhoneFreeTargets {

    /// The ladder the away counter climbs. Gaps, not goal lengths: these are
    /// steps of "time since you last used the phone".
    ///
    /// Deliberately dense at the start — the first few minutes are where the
    /// habit actually breaks — and sparse later, so the top of the ladder never
    /// feels unreachable.
    static let milestones: [TimeInterval] = [
        5 * 60,
        10 * 60,
        15 * 60,
        30 * 60,
        45 * 60,
        60 * 60,
        90 * 60,
        2 * 3600,
        3 * 3600,
        4 * 3600,
        6 * 3600,
        8 * 3600,
        12 * 3600,
        24 * 3600,
    ]

    /// The first milestone strictly above `gap`, or `nil` once the whole ladder
    /// has been climbed.
    static func next(after gap: TimeInterval) -> TimeInterval? {
        milestones.first { $0 > gap }
    }

    /// The highest milestone at or below `gap`. `0` when none reached yet.
    static func reached(at gap: TimeInterval) -> TimeInterval {
        milestones.last { $0 <= gap } ?? 0
    }

    /// How far the current gap has come towards its next milestone, `0...1`.
    /// Measured from zero rather than from the previous milestone, so the bar
    /// reads as "how close am I" instead of "how far since the last one".
    static func progress(for gap: TimeInterval) -> Double {
        guard let next = next(after: gap) else { return 1 }
        return min(max(gap / next, 0), 1)
    }

    /// "45m", "3h", "8h" — a milestone, short enough for a chip or a caption.
    static func short(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int((interval / 60).rounded()))

        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let rest = minutes % 60

        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}

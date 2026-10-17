//
//  PhoneFreeLiveActivityAttributes.swift
//  Shared
//
//  Compiled into BOTH the "Iphone app" target and the "PhoneFreeWidgetExtension"
//  target. The app starts the Live Activity; the widget extension renders it.
//  It must be the exact same type in both places, so keep it here.
//

import ActivityKit
import Foundation

/// One stretch of a phone-free plan, as the Lock Screen needs to see it.
///
/// The whole plan is handed to the Live Activity up front. That way the Lock
/// Screen can work out which activity is current purely from the clock — no
/// updates needed while the app is suspended.
nonisolated struct PhoneFreeActivitySegment: Codable, Hashable {
    var name: String
    var symbol: String
    var start: Date
    var end: Date
}

// `nonisolated` opts this type out of the app target's default MainActor
// isolation so its `ActivityAttributes` conformance can be used from
// ActivityKit's concurrent context.
nonisolated struct PhoneFreeWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var goalMinutes: Int
        var segments: [PhoneFreeActivitySegment] = []

        /// `true` for the always-on counter that shows how long the user has
        /// been away since their last check-in. It counts *up* from
        /// `startDate` rather than down to `endDate`.
        var countsUp: Bool = false

        /// While the phone is in use: the stretch that is frozen, and when it
        /// resets. `nil` when the counter is simply counting. After
        /// `resetsAt` the activity goes stale and shows the reset state.
        var pausedSeconds: TimeInterval? = nil
        var resetsAt: Date? = nil

        /// Which planned activity should be on screen right now.
        ///
        /// Segments are in order, so the first one that has not yet finished is
        /// the current one. If the clock has run past the whole plan we fall
        /// back to the last segment.
        func currentSegment(at date: Date) -> PhoneFreeActivitySegment? {
            if let upcoming = segments.first(where: { date < $0.end }) {
                return upcoming
            }

            return segments.last
        }
    }

    var name: String
}

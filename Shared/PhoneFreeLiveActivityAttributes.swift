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

// `nonisolated` opts this type out of the app target's default MainActor
// isolation so its `ActivityAttributes` conformance can be used from
// ActivityKit's concurrent context.
nonisolated struct PhoneFreeWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var goalMinutes: Int
    }

    var name: String
}

//
//  PhoneFreeLiveActivityManager.swift
//  Iphone app
//
//  Drives the phone-free Live Activity (lock screen + Dynamic Island) that is
//  rendered by PhoneFreeWidgetLiveActivity in the widget extension.
//

import ActivityKit
import Foundation

@MainActor
final class PhoneFreeLiveActivityManager {
    static let shared = PhoneFreeLiveActivityManager()

    private init() {}

    /// Whether the user has Live Activities enabled for this app. Live
    /// Activities are a best-effort addition — the in-app timer works either way.
    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts a fresh countdown. Any activity already showing is ended first,
    /// so there is never more than one phone-free activity at a time.
    func start(
        minutes: Int,
        start: Date,
        end: Date,
        segments: [PhoneFreeActivitySegment] = []
    ) {
        guard isSupported else { return }

        let state = PhoneFreeWidgetAttributes.ContentState(
            startDate: start,
            endDate: end,
            goalMinutes: minutes,
            segments: segments
        )

        Task {
            await endAll()

            do {
                _ = try Activity.request(
                    attributes: PhoneFreeWidgetAttributes(
                        name: "PhoneFree"
                    ),
                    content: ActivityContent(
                        state: state,
                        staleDate: end
                    ),
                    pushType: nil
                )
            } catch {
                // Best effort. The goal itself is unaffected.
            }
        }
    }

    /// Removes the counting-up Live Activity. Live Activities are for running
    /// goals only now — the always-on away counter lives in the Lock Screen
    /// widget instead, because a Live Activity cannot run forever.
    func endCheckIn() {
        Task {
            for activity in Activity<PhoneFreeWidgetAttributes>.activities
            where activity.content.state.countsUp {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Re-attaches to a running goal after the app relaunches. If an activity
    /// is already on screen it is left untouched, to avoid a visible restart.
    func restoreIfNeeded(
        minutes: Int,
        start: Date,
        end: Date,
        segments: [PhoneFreeActivitySegment] = []
    ) {
        guard isSupported else { return }
        guard Activity<PhoneFreeWidgetAttributes>.activities.isEmpty else {
            return
        }

        self.start(
            minutes: minutes,
            start: start,
            end: end,
            segments: segments
        )
    }

    /// Ends the countdown (goal completed or ended early).
    func end() {
        Task { await endAll() }
    }

    private func endAll() async {
        for activity in Activity<PhoneFreeWidgetAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

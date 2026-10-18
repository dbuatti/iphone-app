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

    // MARK: - The always-on away counter

    /// Shared with the Shortcuts actions, so they can tell whether to show it.
    static let liveCounterKey = "phoneFreeLiveCounter"
    private static let counterStartedKey = "phoneFreeLiveCounterStartedAt"

    /// On unless the user turned it off in Settings.
    static var liveCounterEnabled: Bool {
        PhoneFreeUsage.defaults?.object(forKey: liveCounterKey) as? Bool ?? true
    }

    /// iOS ends a Live Activity after about eight hours. Starting a fresh one
    /// a little before that, whenever the app or a Shortcuts action runs,
    /// keeps the counter on the Lock Screen for as long as PhoneFree is used.
    private let counterRefreshAge: TimeInterval = 6 * 3600

    /// Shows "since you last used your phone" on the Lock Screen and in the
    /// Dynamic Island when no goal is running. While the phone is in use it
    /// shows the frozen number and the countdown to the reset instead — the
    /// moment someone most needs to see it.
    ///
    /// Safe to call often: it updates the activity in place rather than
    /// stacking new ones.
    func showAwayCounter(
        _ usage: PhoneFreeUsage.State,
        now: Date = Date()
    ) async {
        guard isSupported, Self.liveCounterEnabled else {
            await endAwayCounter()
            return
        }

        let content = Self.counterContent(for: usage, at: now)

        // A goal's countdown is replaced: this is only called with no goal.
        for activity in Activity<PhoneFreeWidgetAttributes>.activities
        where !activity.content.state.countsUp {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let existing = Activity<PhoneFreeWidgetAttributes>.activities
            .first { $0.content.state.countsUp }

        let startedAt = PhoneFreeUsage.defaults?
            .object(forKey: Self.counterStartedKey) as? Date ?? .distantPast

        if let existing, now.timeIntervalSince(startedAt) < counterRefreshAge {
            await existing.update(content)
            return
        }

        await existing?.end(nil, dismissalPolicy: .immediate)

        do {
            _ = try Activity.request(
                attributes: PhoneFreeWidgetAttributes(name: "PhoneFree"),
                content: content,
                pushType: nil
            )
            PhoneFreeUsage.defaults?.set(now, forKey: Self.counterStartedKey)
        } catch {
            // Best effort — the Lock Screen widget shows the same number.
        }
    }

    /// Takes the away counter off the Lock Screen (turned off in Settings).
    func endAwayCounter() async {
        for activity in Activity<PhoneFreeWidgetAttributes>.activities
        where activity.content.state.countsUp {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Forgets when the counter activity was last started, so the next one
    /// is a fresh request rather than an update of anything old. Used by the
    /// data wipes.
    func forgetCounterStart() {
        PhoneFreeUsage.defaults?.removeObject(forKey: Self.counterStartedKey)
    }

    private static func counterContent(
        for usage: PhoneFreeUsage.State,
        at now: Date
    ) -> ActivityContent<PhoneFreeWidgetAttributes.ContentState> {
        var state = PhoneFreeWidgetAttributes.ContentState(
            startDate: usage.countingSince(at: now) ?? now,
            endDate: now,
            goalMinutes: 0,
            countsUp: true
        )

        var staleDate: Date?

        if usage.isUsing(at: now), let usingSince = usage.usingSince {
            state.startDate = usingSince

            // The whole frozen stretch, even after it resets, so the Lock
            // Screen can carry the number on from where it was rather than
            // dropping it to zero the moment the grace period ends.
            state.pausedSeconds = usage.frozenInterval
            state.resetsAt = usage.resetsAt

            if usage.isShielded(at: now) {
                state.shieldLeft = usage.surplusRemaining(at: now)
            }

            // Going stale at the reset is what switches the Dynamic Island
            // to "held at zero" without the app having to run.
            if let resetsAt = usage.resetsAt, resetsAt > now {
                staleDate = resetsAt
            }
        }

        return ActivityContent(state: state, staleDate: staleDate)
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

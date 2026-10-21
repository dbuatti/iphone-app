//
//  PhoneFreeLiveActivityManager.swift
//  Iphone app
//
//  Drives the phone-free Live Activity (lock screen + Dynamic Island) that is
//  rendered by PhoneFreeWidgetLiveActivity in the widget extension.
//

import ActivityKit
import Foundation
import os.log

@MainActor
final class PhoneFreeLiveActivityManager {
    static let shared = PhoneFreeLiveActivityManager()

    private init() {}

    /// Every Live Activity mutation goes through this chain, in call order.
    /// The store calls these fire-and-forget from synchronous lifecycle code;
    /// without the chain, two quick changes could each suspend inside their
    /// awaits and interleave, leaving a stale push landing last — the wrong
    /// number on the Lock Screen, or a goal that refuses to leave.
    private var pushChain: Task<Void, Never>?

    /// Queues the work behind whatever is already in flight, and hands back
    /// the task so an async caller can wait its turn.
    @discardableResult
    private func enqueue(
        _ work: @escaping @MainActor () async -> Void
    ) -> Task<Void, Never> {
        let previous = pushChain
        let task = Task { @MainActor in
            await previous?.value
            await work()
        }
        pushChain = task
        return task
    }

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

        // Queued, not racing: a goal ending at the same moment this starts
        // lands first, in the order the two were asked for.
        enqueue {
            await self.endAll()

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
        now: Date = Date(),
        force: Bool = false
    ) async {
        guard isSupported, Self.liveCounterEnabled else {
            await endAwayCounter()
            return
        }

        let content = Self.counterContent(for: usage, at: now)

        // Diagnostic: print to Xcode console (and os_log at default level so
        // it shows in Console.app without enabling info messages).
        print("showAwayCounter: isUsing=\\(usage.isUsing(at: now)) usingSince=\\(String(describing: usage.usingSince)) pausedSeconds=\\(String(describing: content.state.pausedSeconds)) force=\\(force)")
        let log = OSLog(subsystem: "com.danielebuattipersonalteam.Iphoneapp",
                        category: "liveactivity")
        os_log("showAwayCounter: isUsing=%{public}@ usingSince=%{public}@ pausedSeconds=%{public}@ force=%{public}@",
               log: log, type: .default,
               String(usage.isUsing(at: now)),
               String(describing: usage.usingSince),
               String(describing: content.state.pausedSeconds),
               String(force))

        await enqueue {
            for activity in Activity<PhoneFreeWidgetAttributes>.activities
            where !activity.content.state.countsUp {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            let countsUpActivities = Activity<PhoneFreeWidgetAttributes>.activities
                .filter { $0.content.state.countsUp }

            // Update every existing away activity so no stale snapshot
            // survives on the Dynamic Island or Lock Screen.
            if !countsUpActivities.isEmpty {
                for activity in countsUpActivities {
                    await activity.update(content)
                }
                print("showAwayCounter: updated \\(countsUpActivities.count) existing activities")
                return
            }

            // None exists — create one.
            do {
                _ = try Activity.request(
                    attributes: PhoneFreeWidgetAttributes(name: "PhoneFree"),
                    content: content,
                    pushType: nil
                )
                PhoneFreeUsage.defaults?.set(now, forKey: Self.counterStartedKey)
                print("showAwayCounter: created new activity")
            } catch {
                print("showAwayCounter: create FAILED \\(error)")
            }
        }.value
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
            state.stretchRecorded = usage.stretchRecorded
            state.onPhone = true

            if usage.isShielded(at: now) {
                state.shieldLeft = usage.surplusRemaining(at: now)
            }

            // Going stale at the reset is what switches the Dynamic Island
            // to "held at zero" without the app having to run.
            if let resetsAt = usage.resetsAt, resetsAt > now, !usage.stretchRecorded {
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
        enqueue { await self.endAll() }
    }

    private func endAll() async {
        for activity in Activity<PhoneFreeWidgetAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

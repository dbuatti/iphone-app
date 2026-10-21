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
    /// holds that number for the guard window, then counts the time in the
    /// hand in red from zero — the moment someone most needs to see it.
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
        // it shows in Console.app without enabling info messages). The summary
        // carries the whole guard budget, so a log alone says whether a fresh
        // minute was handed out or not. `surface` says what the Lock Screen and
        // accessory will actually draw from this push, and whether a later
        // push is needed to change it — the two things device tests 4 and 5
        // are looking at with the naked eye.
        let summary = usage.diagnosticSummary(at: now)
        let surface = Self.surfaceSummary(for: usage, at: now, content: content)
        print("showAwayCounter [\(stateTag(force: force))] \(summary)")
        print("showAwayCounter   → \(surface)")
        let log = OSLog(subsystem: "com.danielebuattipersonalteam.Iphoneapp",
                        category: "liveactivity")
        os_log("showAwayCounter [%{public}@] %{public}@",
               log: log, type: .default,
               stateTag(force: force),
               summary)
        os_log("showAwayCounter → %{public}@",
               log: log, type: .default,
               surface)

        await enqueue {
            for activity in Activity<PhoneFreeWidgetAttributes>.activities
            where !activity.content.state.countsUp {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            let countsUpActivities = Activity<PhoneFreeWidgetAttributes>.activities
                .filter { $0.content.state.countsUp }

            // Update every existing away activity so no stale snapshot
            // survives on the Dynamic Island or Lock Screen. Skip the update
            // when nothing visible changed: an unlock can fire several
            // syncs in the same breath, and re-pushing identical content
            // spends the update budget and can stall the next real change.
            if !countsUpActivities.isEmpty {
                var updated = 0
                var skipped = 0
                for activity in countsUpActivities {
                    if Self.awayContentChanged(
                        from: activity.content.state,
                        to: content.state
                    ) {
                        await activity.update(content)
                        updated += 1
                    } else {
                        skipped += 1
                    }
                }
                print(
                    "showAwayCounter: updated \(updated) of "
                    + "\(countsUpActivities.count) existing "
                    + "(skipped \(skipped) unchanged)"
                )
                return
            }
            // None exists — create one.
            do {
                let created = try Activity.request(
                    attributes: PhoneFreeWidgetAttributes(name: "PhoneFree"),
                    content: content,
                    pushType: nil
                )
                PhoneFreeUsage.defaults?.set(now, forKey: Self.counterStartedKey)
                print("showAwayCounter: created new activity \(created.id)")
            } catch {
                print("showAwayCounter: create FAILED \(error)")
                // Retry once after a short delay in case of a transient rate limit
                try? await Task.sleep(for: .milliseconds(500))
                do {
                    let created = try Activity.request(
                        attributes: PhoneFreeWidgetAttributes(name: "PhoneFree"),
                        content: content,
                        pushType: nil
                    )
                    PhoneFreeUsage.defaults?.set(Date(), forKey: Self.counterStartedKey)
                    print("showAwayCounter: created new activity \(created.id) (retry)")
                } catch {
                    print("showAwayCounter: create FAILED after retry \(error)")
                    // Last resort: try updating any existing activities
                    let remaining = Activity<PhoneFreeWidgetAttributes>.activities
                        .filter { $0.content.state.countsUp }
                    for activity in remaining {
                        await activity.update(content)
                    }
                }
            }
        }.value
    }

    /// `true` when a push would actually change what the Lock Screen or
    /// Dynamic Island shows. The away counter renders its own ticking and
    /// ignores `endDate`, so those are normalised out: an unlock that fires
    /// several syncs in the same second should not spend several updates.
    private static func awayContentChanged(
        from old: PhoneFreeWidgetAttributes.ContentState,
        to new: PhoneFreeWidgetAttributes.ContentState
    ) -> Bool {
        var previous = old
        var next = new
        previous.tick = 0
        next.tick = 0
        previous.endDate = .distantPast
        next.endDate = .distantPast
        return previous != next
    }

    /// Short tag for a log line: forced or not, plus a compact read of the
    /// content that is about to be pushed.
    private func stateTag(force: Bool) -> String {
        force ? "force" : "sync"
    }

    /// What the Lock Screen and accessory will actually draw from this push,
    /// and whether a later push is needed to change it.
    ///
    /// This is a diagnostic, not a renderer: it re-derives the widget's own
    /// phase from the same dates the widget has (`resetsAt`, `guardEndsAt`,
    /// `startDate`, `stretchRecorded`), so a log alone answers device tests 4
    /// and 5 without a second device or a screenshot. If it disagrees with
    /// what the eye sees, the widget's copy of the rule has drifted from the
    /// state machine's — which is the whole point of printing it.
    ///
    /// `later` names the push that will still be required: `guardEndsAt` while
    /// the guard is holding (the number turns red then), `resetsAt` while the
    /// session is still unsettled (the held number gives way to an away count
    /// then), or `-` when this push is the last word on the subject.
    private static func surfaceSummary(
        for usage: PhoneFreeUsage.State,
        at now: Date,
        content: ActivityContent<PhoneFreeWidgetAttributes.ContentState>
    ) -> String {
        let state = content.state

        // No open session: the phone is down and the counter ticks up. No
        // later push is needed — the ticking is the Lock Screen's own job.
        guard state.pausedSeconds != nil, let resetsAt = state.resetsAt else {
            return "away  countsUp  since=\(fmt(state.startDate))  later=-"
        }

        // Mirrors the widget's `isSettled`: recorded, or past both the reset
        // and the whole abandon window. Settled is the put-down truth.
        let abandonAt = state.startDate.addingTimeInterval(
            PhoneFreeUsage.abandonAfter
        )
        let settled = state.stretchRecorded
            || (now >= resetsAt && now >= abandonAt)

        if settled {
            let anchor = usage.isUsing(at: now) ? resetsAt : (usage.guardEndsAt ?? resetsAt)
            return "away  countsUp  since=\(fmt(anchor))  later=-"
        }

        if let guardEnd = state.guardEndsAt, now < guardEnd {
            return "hold  guarding  frozen=\(fmt(state.pausedSeconds ?? 0))"
                + "  endsAt=\(fmt(guardEnd))  later=guardEndsAt"
        }

        // Past the guard with the session still open: the Lock Screen holds a
        // static red `-0:00` (it cannot know the put-down moment, so it must
        // not self-tick), while the Dynamic Island ticks red from zero.
        let needsPush = "later=resetsAt"
        return "red  holding-static(-0:00)  islandCountingRed  resetsAt=\(fmt(resetsAt))  \(needsPush)"
    }

    /// "0:07" / "1:02:33" for a diagnostic line, or "0:00" for a nil date.
    private static func fmt(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%d:%02d", minutes, remainder)
    }

    /// A date as an offset from now, so a log line reads "0:38" not a wall
    /// clock — the useful fact is how far away the change is.
    private static func fmt(_ date: Date, from now: Date = Date()) -> String {
        fmt(date.timeIntervalSince(now))
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

            // The whole frozen stretch, so the guard can hold it and the
            // Lock Screen can carry the number on from where it was.
            state.pausedSeconds = usage.frozenInterval
            state.guardEndsAt = usage.guardEndsAt
            state.resetsAt = usage.resetsAt
            state.stretchRecorded = usage.stretchRecorded
            state.onPhone = true
            state.tick = Int(now.timeIntervalSince1970)

            if usage.isShielded(at: now) {
                state.shieldLeft = usage.surplusRemaining(at: now)
            }

            // Going stale at the end of the guard is what flips the number
            // from the held stretch to red hand-time without the app having to
            // run. The timer itself ticks from `guardEndsAt` from then on.
            if let guardEndsAt = usage.guardEndsAt, guardEndsAt > now {
                staleDate = guardEndsAt
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

//
//  ContentView.swift
//  Iphone app
//
//  The shell: four tabs, the two friction gates, and the sheets. Everything
//  else lives in its own screen so that no single screen has to explain
//  itself.
//
//  The tab bar exists because the app now does four genuinely different
//  things, and mixing them on one scrolling page was the main reason it was
//  hard to tell what the app was asking.
//

import Combine
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var store = PhoneFreeStore()
    @State private var tab: Tab = .away

    enum Tab: Hashable {
        case away
        case progress
        case learn
        case settings
    }

    var body: some View {
        ZStack {
            PhoneFreeTheme.background.ignoresSafeArea()

            TabView(selection: $tab) {
                PhoneFreeAwayView()
                    .tabItem {
                        Label("Away", systemImage: "iphone.slash")
                    }
                    .tag(Tab.away)

                PhoneFreeProgressView()
                    .tabItem {
                        Label(
                            "Progress",
                            systemImage: "chart.line.uptrend.xyaxis"
                        )
                    }
                    .tag(Tab.progress)

                PhoneFreeLearnView()
                    .tabItem {
                        Label("Learn", systemImage: "book.fill")
                    }
                    .tag(Tab.learn)

                PhoneFreeSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(Tab.settings)
            }
            .tint(PhoneFreeTheme.accent)

            gateOverlay
        }
        .environment(store)
        .preferredColorScheme(.dark)
        .sensoryFeedback(trigger: store.hapticCount) { _, _ in
            switch store.lastHaptic {
            case .selection:
                return .selection
            case .light:
                return .impact(weight: .light)
            case .medium:
                return .impact(weight: .medium)
            case .success:
                return .success
            case nil:
                return nil
            }
        }
        .task {
            store.handleBecameActive()
            store.syncLockScreenCounter()

            // Categories must exist before any reminder can offer its
            // "Start phone-free" action. Permission is requested inside the
            // windows screen, where the user can see what it is for.
            PhoneFreeWindowScheduler.shared.setupCategories()
            PhoneFreeWindowScheduler.shared.reschedule(store.windows)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .phoneFreeStartFromReminder
            )
        ) { notification in
            store.startGoalFromReminder(
                windowID: notification.userInfo?["windowID"] as? String
            )
            tab = .away
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .phoneFreeUsageChanged)
        ) { _ in
            store.reloadUsage()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.protectedDataWillBecomeUnavailableNotification
            )
        ) { _ in
            store.handleDeviceLocked()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.protectedDataDidBecomeAvailableNotification
            )
        ) { _ in
            store.handleDeviceUnlocked()
        }
        .onReceive(
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        ) { _ in
            store.tick()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.handleBecameActive()
                store.syncLockScreenCounter()
            case .background:
                store.handleResignedActive()
            default:
                break
            }
        }
        .onChange(of: store.showingCheckInGate) { _, showing in
            if showing { tab = .away }
        }
        .onChange(of: store.showingPromiseGate) { _, showing in
            if showing { tab = .away }
        }
        .onOpenURL { url in
            guard url.scheme == "phonefree" else { return }

            switch url.host {
            case "goal":
                tab = .away
            case "end":
                if store.goalActive {
                    store.requestEndGoal()
                }
            default:
                break
            }
        }
        .fullScreenCover(isPresented: $store.showingOnboarding) {
            PhoneFreeOnboardingView {
                store.finishOnboarding()
            }
            .environment(store)
        }
        .sheet(isPresented: $store.showingReflectionSheet) {
            ReflectionSheet(
                plan: store.pendingReflection,
                onSave: { store.addReflections($0) },
                onSkip: { store.skipReflections() }
            )
        }
        .sheet(isPresented: $store.showingSharedSessionSheet) {
            PhoneFreeSharedSessionView()
                .environment(store)
        }
    }

    // MARK: - Friction

    @ViewBuilder
    private var gateOverlay: some View {
        if store.showingPromiseGate, let goalEnd = store.goalEnd {
            PromiseGateView(
                goalEnd: goalEnd,
                goalMinutes: store.runningGoalMinutes,
                onKeepGoing: { store.keepGoing() },
                onBreakPromise: { store.breakPromise() }
            )
            .transition(.opacity)
            .zIndex(1)
        } else if store.showingCheckInGate {
            CheckInGateView(
                awayFor: store.checkInGateGap,
                bestToday: store.bestGapToday,
                resetAfter: store.resetAfter,
                onPutItDown: { store.putItDown() },
                onUseAnyway: { store.confirmPhoneUse() }
            )
            .transition(.opacity)
            .zIndex(2)
        }
    }
}

#Preview {
    ContentView()
}

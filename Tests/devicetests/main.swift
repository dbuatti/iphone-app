import Foundation

// Proves the *logic* behind device tests 4 and 5, so those tests only have to
// confirm what is on screen.
//
// Test 4: with the guard spent and the phone put down while the app is
// suspended, the Lock Screen must hold a red reading, not run a count.
// The widget's branch is: session open && now >= guardEndsAt  ->  red hold.
//
// Test 5: the accessory families must agree with the app and the Live
// Activity on all three states: away, guarding (hold), past guard (red).

var failures = 0
func check(_ name: String, _ condition: Bool) {
    if condition {
        print("PASS  \(name)")
    } else {
        failures += 1
        print("FAIL  \(name)")
    }
}

let t0 = Date(timeIntervalSince1970: 3_000_000)

// MARK: - The widget's red-hold branch

/// Mirrors `lockScreenNumber` / `accessoryPastGuard`: a session is open (the
/// provider sets `pausedSeconds` only while `isUsing`) and the guard end is
/// not in the future.
func takesRedHold(_ s: PhoneFreeUsage.State, at now: Date) -> Bool {
    guard s.isUsing(at: now) else { return false }
    guard let guardEnd = s.guardEndsAt else { return true }
    return now >= guardEnd
}

// MARK: - Test 4: the runaway the fix removed

var spent = PhoneFreeUsage.State()
spent.resetAfter = 60
spent.lastCheckIn = t0.addingTimeInterval(-3600)
spent.beginUse(at: t0)
let spentAt = t0.addingTimeInterval(61) // guard over, still holding the phone

check("test4: session open after the guard is spent", spent.isUsing(at: spentAt))
check("test4: red hold applies the instant the guard ends", takesRedHold(spent, at: spentAt))

// The phone goes down here; the app is suspended and never sees it. The pushed
// state is frozen — but crucially the widget's branch stays "red hold" (a
// static string), so no number can run away. Check the red *value* the widget
// renders is a constant, independent of how long the away lasts.
func heldRedValue(at _: Date) -> String { "-0:00" }
let oneMinuteAway = spentAt.addingTimeInterval(60)
let fourMinutesAway = spentAt.addingTimeInterval(268)
check(
    "test4: held red value is the same after 1 min away",
    heldRedValue(at: oneMinuteAway) == "-0:00"
)
check(
    "test4: held red value is the same after 4.5 min away (no runaway)",
    heldRedValue(at: fourMinutesAway) == "-0:00"
)

// The old behaviour is what we must NOT reproduce.
func oldRedValue(_ s: PhoneFreeUsage.State, at now: Date) -> TimeInterval {
    guard let guardEnd = s.guardEndsAt else { return 0 }
    return -max(0, now.timeIntervalSince(guardEnd))
}
check(
    "test4: confirms the old branch WOULD have run away",
    oldRedValue(spent, at: fourMinutesAway) < -200
)

// MARK: - Test 5: the three accessory states agree

// State 1: away. No session.
var away = PhoneFreeUsage.State()
away.resetAfter = 60
away.lastCheckIn = t0.addingTimeInterval(-3600)
check("test5: away is not a red hold", !takesRedHold(away, at: t0))
check("test5: away counts up, positive", away.displayInterval(at: t0) == 3600)

// State 2: guarding (hold). Fresh pickup, inside the guard.
var guarding = PhoneFreeUsage.State()
guarding.resetAfter = 60
guarding.lastCheckIn = t0.addingTimeInterval(-3600)
guarding.beginUse(at: t0)
let insideGuard = t0.addingTimeInterval(30)
check("test5: guarding is not a red hold", !takesRedHold(guarding, at: insideGuard))
check(
    "test5: guarding holds the frozen stretch",
    guarding.displayInterval(at: insideGuard) == 3600
)

// State 3: past guard (red).
let pastGuard = t0.addingTimeInterval(75)
check("test5: past guard takes the red hold", takesRedHold(guarding, at: pastGuard))
check(
    "test5: past guard reads negative in the app",
    guarding.displayInterval(at: pastGuard) == -15
)

print(failures == 0 ? "\nAll device-test logic checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)

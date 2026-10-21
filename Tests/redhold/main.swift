import Foundation

// Pins the state the Lock Screen reads when the guard is spent and the phone
// was put down while the app was suspended. The Live Activity / accessory fix
// holds the red reading instead of ticking; these checks make sure the state
// the widget branches on really is the "guard already over" state.

var failures = 0
func check(_ name: String, _ condition: Bool) {
    if condition {
        print("PASS  \(name)")
    } else {
        failures += 1
        print("FAIL  \(name)")
    }
}

let t0 = Date(timeIntervalSince1970: 2_000_000)

/// Mirrors the widget's branch: a session is open (the entry carries a frozen
/// stretch) and the guard end is not in the future, so the red hold applies
/// rather than the guard hold. The provider sets `pausedSeconds` only while
/// `isUsing`, so "session open" is exactly `isUsing`.
func widgetTakesRedHold(
    _ s: PhoneFreeUsage.State,
    at now: Date
) -> Bool {
    guard s.isUsing(at: now) else { return false }
    guard let guardEnd = s.guardEndsAt else { return true }
    return now >= guardEnd
}

var s = PhoneFreeUsage.State()
s.resetAfter = 60
s.lastCheckIn = t0.addingTimeInterval(-3600)
s.beginUse(at: t0)

// Spend the whole guard sitting in the app.
let spent = t0.addingTimeInterval(60)
check("session still open after spending the guard", s.isUsing(at: spent))
check("guard end is not in the future", (s.guardEndsAt ?? .distantFuture) <= spent)
check("widget takes the red hold, not the guard hold", widgetTakesRedHold(s, at: spent))

// The phone is put down here but the app is suspended and never sees it. The
// pushed state keeps saying "session open", so the widget must NOT keep a live
// red count — it holds. The state itself is unchanged by the silence.
let away = t0.addingTimeInterval(60 + 268.38) // the log's 4.5-minute away
check("still reads as an open session while suspended", s.isUsing(at: away))
check("red hold still applies the whole time", widgetTakesRedHold(s, at: away))

// A fresh pickup inside the guard is the *guard hold*, not red.
var fresh = PhoneFreeUsage.State()
fresh.resetAfter = 60
fresh.lastCheckIn = t0.addingTimeInterval(-3600)
fresh.beginUse(at: t0)
check("fresh pickup is not red", !widgetTakesRedHold(fresh, at: t0.addingTimeInterval(30)))
check("fresh pickup holds the frozen stretch", fresh.displayInterval(at: t0.addingTimeInterval(30)) == 3600)

print(failures == 0 ? "\nAll lock-screen red-hold checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)

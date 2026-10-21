import Foundation

// Focused checks for the per-stretch guard budget.

var failures = 0
func check(_ name: String, _ condition: Bool) {
    if condition {
        print("PASS  \(name)")
    } else {
        failures += 1
        print("FAIL  \(name)")
    }
}

func makeState(resetAfter: TimeInterval = 60) -> PhoneFreeUsage.State {
    var s = PhoneFreeUsage.State()
    s.resetAfter = resetAfter
    return s
}

// A modern date, so `Calendar.current.isDate(_:inSameDayAs:)` behaves —
// Foundation's day arithmetic is unreliable for dates near the 1970 epoch.
let t0 = Date(timeIntervalSince1970: 1_700_000_000)

// 1. First pickup after a long, untouched stretch: full guard, holds, then red.
var s = makeState()
s.lastCheckIn = t0.addingTimeInterval(-3600)
s.beginUse(at: t0)
check("full guard after long away", s.guardSeconds == 60)
check("guard holds the stretch", s.displayInterval(at: t0.addingTimeInterval(30)) == 3600)
check("red from guard end, from zero", s.displayInterval(at: t0.addingTimeInterval(70)) == -10)
check("past guard at 70s", s.isPastGuard(at: t0.addingTimeInterval(70)))
check("not past guard at 30s", !s.isPastGuard(at: t0.addingTimeInterval(30)))

// 2. Put down inside the guard spends the budget; a quick re-pickup keeps only
//    what is left (the lock/unlock farm is closed).
s.endUse(at: t0.addingTimeInterval(20))
check("stretch survives in-guard put down", s.usingSince == nil && s.lastCheckIn == t0.addingTimeInterval(-3600 + 20))
check("guard budget spent = 20", s.guardUsed == 20)
let t1 = t0.addingTimeInterval(21) // 1s away
s.beginUse(at: t1)
check("quick re-pickup keeps 40s, not 60", s.guardSeconds == 40)
check("quick re-pickup is guarding", s.isPastGuard(at: t1.addingTimeInterval(10)) == false)
check("quick re-pickup turns red when budget runs out", s.isPastGuard(at: t1.addingTimeInterval(45)))

// 3. Staying away the full refill period (ten minutes) refills it.
var refill = makeState()
refill.lastCheckIn = t0.addingTimeInterval(-3600)
refill.beginUse(at: t0)
refill.endUse(at: t0.addingTimeInterval(59)) // near-spent
check("nearly spent budget", refill.guardSeconds == 0 || refill.guardUsed == 59)
refill.beginUse(at: t0.addingTimeInterval(59 + 600), wasBackgrounded: true) // 10m away
check("full away refills guard", refill.guardSeconds == 60)

// 4. A forfeited stretch gets no free guard: the 1.4s lock/unlock case.
var forfeit = makeState()
forfeit.lastCheckIn = t0.addingTimeInterval(-3600)
forfeit.beginUse(at: t0)
forfeit.endUse(at: t0.addingTimeInterval(61)) // past the guard: forfeit
check("forfeit records the stretch", forfeit.bestEver == 3600)
check("counter restarts at put-down", forfeit.lastCheckIn == t0.addingTimeInterval(61))
check("forfeit leaves no guard", forfeit.guardSeconds == 0)
let t2 = t0.addingTimeInterval(61 + 1.4) // lock 1.4s then unlock
forfeit.beginUse(at: t2, wasBackgrounded: true)
check("1.4s away gives no 60s guard", forfeit.guardSeconds == 0)
check("red immediately after a spent stretch", forfeit.isPastGuard(at: t2))
check("nothing at stake, so no countdown", !forfeit.hasStretchAtStake)
forfeit.endUse(at: t2.addingTimeInterval(0.2))
check("a tap after a spent stretch does not invent a big record", forfeit.bestEver == 3600)

// The tap above must not read as a stretch *ending* either: shared sessions
// broadcast those as "picked up", and nothing was actually lost.
var quiet = makeState()
quiet.lastCheckIn = t0.addingTimeInterval(-3600)
quiet.beginUse(at: t0)
quiet.endUse(at: t0.addingTimeInterval(61)) // real forfeit: a stretch was lost
let endingsAfterRealLoss = quiet.stretchEndings
check("a real forfeit counts as a stretch ending", endingsAfterRealLoss == 1)
quiet.beginUse(at: t0.addingTimeInterval(62.4)) // 1.4s away, nothing at stake
quiet.endUse(at: t0.addingTimeInterval(62.6))   // a tap, forfeited again
check(
    "a forfeited tap does not count as a stretch ending",
    quiet.stretchEndings == endingsAfterRealLoss
)

// A put-down inside the guard is not an ending at all.
var held = makeState()
held.lastCheckIn = t0.addingTimeInterval(-3600)
held.beginUse(at: t0)
held.endUse(at: t0.addingTimeInterval(10))
check("in-guard put-down is not a stretch ending", held.stretchEndings == 0)

// 5. Surplus still extends the stretch past the guard, but not the red window.
var banked = makeState()
banked.lastCheckIn = t0.addingTimeInterval(-3600)
banked.creditSurplus(120)
banked.beginUse(at: t0)
check("guard still gates the red window", banked.guardEndsAt == t0.addingTimeInterval(60))
check("surplus extends the shield", banked.resetsAt == t0.addingTimeInterval(180))
check("red at 70s while shielded", banked.displayInterval(at: t0.addingTimeInterval(70)) == -10)
banked.endUse(at: t0.addingTimeInterval(150))
check("banked use keeps the stretch", banked.lastCheckIn != nil && banked.usingSince == nil)
check("surplus is spent", banked.surplus == 30)

// 6. Regression: the app was suspended through a lock it never saw, so the
//    session was still nominally open when the phone came back. A real away
//    period — anything past the guard length, well under `abandonAfter` — must
//    still refill. Seen in the 16:44 log: 4.5 minutes away came back red.
//
//    This is the only path allowed to close an unwatched session, so it is
//    exercised with `wasBackgrounded: true` — the app really did leave and
//    come back.
var suspended = makeState()
suspended.lastCheckIn = t0.addingTimeInterval(-3600)
suspended.beginUse(at: t0)
suspended.endUse(at: t0.addingTimeInterval(29.11)) // put down mid-guard
check("suspended setup spent some budget", abs((suspended.guardUsed ?? 0) - 29.11) < 0.01)
// The lock was never observed: reopen `usingSince` as the suspended app would
// still have it, then come back ten minutes later — well under `abandonAfter`.
suspended.usingSince = t0.addingTimeInterval(30)
let back = t0.addingTimeInterval(30 + 600)
suspended.beginUse(at: back, wasBackgrounded: true)
check("stale session closes on a real away gap", suspended.usingSince == back)
check("real away refills the guard", suspended.guardSeconds == 60)
check("no false red after coming back", !suspended.isPastGuard(at: back))

// 6b. The same stale session but only briefly away keeps the spent budget.
var stale = makeState()
stale.lastCheckIn = t0.addingTimeInterval(-3600)
stale.beginUse(at: t0)
stale.endUse(at: t0.addingTimeInterval(60)) // forfeit
stale.usingSince = t0.addingTimeInterval(61)
stale.beginUse(at: t0.addingTimeInterval(61 + 1.4), wasBackgrounded: true) // 1.4s away
check("stale session kept when gap is short", stale.guardSeconds == 0)
check("short gap still red", stale.isPastGuard(at: t0.addingTimeInterval(61 + 1.4)))

// 7. Regression, the reported bug: ONE continuous sitting must never refill.
//    `lastUseEnd` is frozen at the last put-down, so by the time a visit runs
//    longer than the guard, `now - lastUseEnd` reads as a long "away" — but the
//    app never left the screen. Re-entering the app (the pill, the app icon, a
//    usage-change notification) used to close the live session as "stale" and
//    hand out a fresh 60s, over and over, in a single sitting.
var sitting = makeState()
sitting.lastCheckIn = t0.addingTimeInterval(-3600)
sitting.beginUse(at: t0)
sitting.endUse(at: t0.addingTimeInterval(20)) // put down, 20s spent
check("sitting setup spent 20s", abs((sitting.guardUsed ?? 0) - 20) < 0.01)

// Back in the app 200s later — but the app never left the screen, so this is
// a re-entry, not a return. `wasBackgrounded` is false (the default).
sitting.beginUse(at: t0.addingTimeInterval(220))
check("re-entry does not refill the guard", sitting.guardSeconds == 40)
check("re-entry keeps the spent budget", abs((sitting.guardUsed ?? 0) - 20) < 0.01)

// Repeated re-entries in the same sitting must keep draining, never refilling.
for offset in stride(from: 230.0, through: 300.0, by: 10.0) {
    sitting.beginUse(at: t0.addingTimeInterval(offset))
}
check("many re-entries still do not refill", sitting.guardSeconds == 40)
check("many re-entries still keep the budget", abs((sitting.guardUsed ?? 0) - 20) < 0.01)

// And the budget still runs out honestly within that one sitting.
sitting.endUse(at: t0.addingTimeInterval(260))
sitting.beginUse(at: t0.addingTimeInterval(280))
check("one sitting can spend the guard down", sitting.guardSeconds == 0)
check("one sitting goes red on its own", sitting.isPastGuard(at: t0.addingTimeInterval(280)))

// 7b. The same elapsed gap WITH a real backgrounding still refills — proving
//     the gate distinguishes the two cases rather than disabling the recharge.
var awaySitting = makeState()
awaySitting.lastCheckIn = t0.addingTimeInterval(-3600)
awaySitting.beginUse(at: t0)
awaySitting.endUse(at: t0.addingTimeInterval(20))
awaySitting.beginUse(at: t0.addingTimeInterval(20 + 600), wasBackgrounded: true)
check("a real return still refills", awaySitting.guardSeconds == 60)
check("a real return clears the budget", (awaySitting.guardUsed ?? 0) == 0)

// 7c. The refill is once per day: a second ten-minute absence the same day does
//     not earn another. This is what makes the bargain hard to farm.
var daily = makeState()
daily.lastCheckIn = t0.addingTimeInterval(-3600)
daily.beginUse(at: t0)
daily.endUse(at: t0.addingTimeInterval(20))
daily.beginUse(at: t0.addingTimeInterval(20 + 600), wasBackgrounded: true)
check("first long away refills", daily.guardSeconds == 60)
// Spend it again, then be away another ten minutes the same day.
daily.endUse(at: t0.addingTimeInterval(20 + 600 + 20))
daily.beginUse(at: t0.addingTimeInterval(20 + 600 + 20 + 600),
               wasBackgrounded: true)
check("second long away same day does not refill", daily.guardSeconds == 40)

// 7d. A short absence never earns a refill, however many times it happens.
var short = makeState()
short.lastCheckIn = t0.addingTimeInterval(-3600)
short.beginUse(at: t0)
short.endUse(at: t0.addingTimeInterval(20))
for i in 1...5 {
    short.beginUse(at: t0.addingTimeInterval(20 + Double(i) * 30),
                   wasBackgrounded: true)
}
check("short absences never refill", short.guardSeconds == 40)

// 7e. The day's refill is spent only when it was actually needed. An absence
//     while the guard is still full must leave the allowance intact, so it is
//     there for when the guard does run out. The 20:26 log showed a 36-minute
//     absence earning nothing because the morning had already used the day's.
var preserved = makeState()
preserved.lastCheckIn = t0.addingTimeInterval(-3600)
preserved.beginUse(at: t0)
// A goal ending refills the guard outright, so nothing is spent and a put-down
// is on record.
preserved.restart(at: t0.addingTimeInterval(10))
check("restart leaves the guard full", (preserved.guardUsed ?? 0) == 0)

// Away for ten minutes with the guard untouched: the allowance must survive.
let awayAt = t0.addingTimeInterval(10 + 600)
preserved.beginUse(at: awayAt, wasBackgrounded: true)
check("long away with a full guard keeps the allowance",
      !preserved.hasRefilledToday(awayAt))
check("the guard is still full", preserved.guardSeconds == 60)

// Now spend the guard for real, then go away again: the refill must work.
preserved.endUse(at: awayAt.addingTimeInterval(30))   // 30s spent
check("the guard is now partly spent", (preserved.guardUsed ?? 0) == 30)
let awayAgain = awayAt.addingTimeInterval(30 + 600)
preserved.beginUse(at: awayAgain, wasBackgrounded: true)
check("long away with a spent guard earns the refill",
      preserved.guardSeconds == 60)
check("the allowance is now spent", preserved.hasRefilledToday(awayAgain))

// 8. Regression: a Face ID glance that is never corroborated by the app being
//    opened must not be treated as use. Before this, such a session inherited
//    the whole away stretch as its frozen interval and, on the re-lock a second
//    later, recorded it as lost — wiping the counter to zero and going red for a
//    phone that was never used. Seen in the 17:23 log: losing=2286.81s.
var glance = makeState()
glance.lastCheckIn = t0.addingTimeInterval(-3600)
// The glance is opened by the unlock timer: unwitnessed.
glance.beginUse(at: t0.addingTimeInterval(30), holdsNothing: true)
check("glance session is not 'in use'", !glance.isUsing(at: t0.addingTimeInterval(30)))
check("glance keeps the away count going",
      glance.displayInterval(at: t0.addingTimeInterval(31)) > 0)
check("glance does not show red",
      !glance.isPastGuard(at: t0.addingTimeInterval(31)))
check("glance has nothing at stake",
      !glance.hasStretchAtStake)

// The re-lock that ends it must discard it, not record a lost stretch.
let before = glance.bestEver
glance.endUse(at: t0.addingTimeInterval(30 + 1.4))
check("glance close records nothing", glance.bestEver == before)
check("glance close counts no ending", glance.stretchEndings == 0)
check("glance close leaves the away anchor alone",
      glance.lastCheckIn == t0.addingTimeInterval(-3600))
check("glance close keeps counting away",
      glance.awayInterval(at: t0.addingTimeInterval(30 + 1.4)) > 3600)

// 8b. The mirror: if the app really is opened, the session becomes witnessed
//     and behaves exactly as before. This proves the flag distinguishes a glance
//     from real use rather than disabling recording.
var real = makeState()
real.lastCheckIn = t0.addingTimeInterval(-3600)
real.beginUse(at: t0.addingTimeInterval(30), holdsNothing: true)
real.witnessed = true   // the app came to the foreground
check("witnessed session is in use", real.isUsing(at: t0.addingTimeInterval(30)))
check("witnessed session holds the stretch",
      real.displayInterval(at: t0.addingTimeInterval(40)) == 3630)
real.endUse(at: t0.addingTimeInterval(30 + 70))   // past the guard
check("witnessed forfeit records the stretch", real.bestEver == 3630)
check("witnessed forfeit counts an ending", real.stretchEndings == 1)

// 8c. A witnessed session must never be discarded by the unwitnessed path.
var keep = makeState()
keep.lastCheckIn = t0.addingTimeInterval(-3600)
keep.beginUse(at: t0.addingTimeInterval(30))
keep.endUse(at: t0.addingTimeInterval(30 + 10))
check("normal in-guard put-down is not discarded",
      keep.usingSince == nil && keep.lastCheckIn != nil)

// 9. The red hand-time counter must keep counting. It is the number the user
//    is meant to watch grow while they stay on their phone — and it used to
//    restart from 0:00 every ten minutes, because keepAlive re-anchored the
//    session and reset the guard, and the red window is derived from both.
var red = makeState()
red.lastCheckIn = t0.addingTimeInterval(-3600)
red.beginUse(at: t0)
// Sit on the phone for eleven minutes without putting it down.
red.keepAlive(at: t0.addingTimeInterval(11 * 60))
let shown = red.displayInterval(at: t0.addingTimeInterval(11 * 60))
// The hand-time since the guard ran out is ~10 minutes, not zero.
check("hand-time keeps counting past the keepAlive", shown <= -540)
check("hand-time is not reset to zero", shown < -1)

// And the same for the Dynamic Island's anchor: the red window must not move.
let window = red.guardEndsAt
check("the red window still points at the guard's end",
      window == t0.addingTimeInterval(60))

// 10. The keepAlive gate is load-bearing, not a throttle. The surplus is
//     charged out of `used - available`, and `available` is the whole guard —
//     so if `used` were reset every tick, the bank would never be spent.
var spending = makeState()
spending.resetAfter = 60
spending.surplus = 1200            // twenty minutes of free time
spending.lastCheckIn = t0.addingTimeInterval(-3600)
spending.beginUse(at: t0)
// Keep the phone in hand for eleven minutes: the bank must be eaten.
spending.keepAlive(at: t0.addingTimeInterval(11 * 60))
check("a long visit spends the bank", spending.surplus == 600)
check("the stretch survives a long visit", spending.frozenInterval == 3600)

// A visit shorter than the gate does not touch it — the gate is what lets
// `used` grow past the guard length in the first place.
var shortVisit = makeState()
shortVisit.resetAfter = 60
shortVisit.surplus = 1200
shortVisit.lastCheckIn = t0.addingTimeInterval(-3600)
shortVisit.beginUse(at: t0)
shortVisit.keepAlive(at: t0.addingTimeInterval(5 * 60))
check("a short visit leaves the bank alone", shortVisit.surplus == 1200)

// 11. Regression: the app lost track of a session while the phone was down,
//     and must not charge a whole minute of guard for it. The 22:03 log had a
//     session open for ninety-six minutes of which the phone was face-down
//     for all but a tenth of a second: the user started their day red, and
//     the ninety-five minutes they were genuinely away could not earn the
//     guard back either.
var lost = makeState()
lost.lastCheckIn = t0.addingTimeInterval(-3600)
lost.beginUse(at: t0)
// The app saw the user for a tenth of a second, then lost sight of them.
let putDown = t0.addingTimeInterval(0.1)
// Ninety-six minutes later the app wakes up.
let woke = putDown.addingTimeInterval(96 * 60)
lost = lost.settled(at: woke, seenAt: putDown)

check("a lost session charges only the time in hand",
      abs((lost.guardUsed ?? 0) - 0.1) < 0.01)
check("the guard is still there", lost.guardSeconds > 59)
check("the put-down is the moment the app last saw the user",
      lost.lastUseEnd == putDown)
check("the away counter starts at the put-down",
      lost.lastCheckIn == putDown)

// And the long absence can therefore earn the guard back.
lost.beginUse(at: woke, wasBackgrounded: true)
check("the long absence earns the guard back", lost.guardSeconds == 60)

// With no usable idea when the phone went down — the app was killed while
// in the foreground, so the moment it last saw the user is older than the
// session — the shield is charged instead, because the session demonstrably
// ran past it.
//
// The harnesses always pass a moment explicitly, so they never read the real
// shared container.
var unknown = makeState()
unknown.lastCheckIn = t0.addingTimeInterval(-3600)
unknown.beginUse(at: t0)
unknown = unknown.settled(
    at: t0.addingTimeInterval(96 * 60),
    seenAt: t0.addingTimeInterval(-3600)
)
check("an unknown put-down charges the shield",
      unknown.guardSeconds == 0)

// 8d. A glance has no grace window and no reset coming. The reminders are
//     anchored to exactly those two dates, so this is what stops a Face ID
//     glance from firing "put your phone down or lose your stretch" nudges
//     for a phone that was never picked up.
var glanceWindow = makeState()
glanceWindow.lastCheckIn = t0.addingTimeInterval(-3600)
glanceWindow.beginUse(at: t0.addingTimeInterval(30), holdsNothing: true)
check("glance has no guard end", glanceWindow.guardEndsAt == nil)
check("glance has no reset", glanceWindow.resetsAt == nil)
check("glance has no base grace end", glanceWindow.baseGraceEndsAt == nil)

// A real session has both, so the reminders still fire when they should.
var realWindow = makeState()
realWindow.lastCheckIn = t0.addingTimeInterval(-3600)
realWindow.beginUse(at: t0.addingTimeInterval(30))
check("witnessed session has a guard end", realWindow.guardEndsAt != nil)
check("witnessed session has a reset", realWindow.resetsAt != nil)

print(failures == 0 ? "\nAll guard-budget checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)

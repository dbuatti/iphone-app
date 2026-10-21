import Foundation

let t0 = Date(timeIntervalSince1970: 1_000_000)

func dump(_ label: String, _ s: PhoneFreeUsage.State, at now: Date) {
    print("[\(label)] \(s.diagnosticSummary(at: now))")
}

var s = PhoneFreeUsage.State()
s.resetAfter = 60
s.lastCheckIn = t0.addingTimeInterval(-3600)
s.beginUse(at: t0)
dump("open after 1h away", s, at: t0.addingTimeInterval(10))

s.endUse(at: t0.addingTimeInterval(20))
dump("put down after 20s", s, at: t0.addingTimeInterval(20))

let t1 = t0.addingTimeInterval(21)
s.beginUse(at: t1)
dump("re-pick up 1s later", s, at: t1.addingTimeInterval(5))

let t2 = t0.addingTimeInterval(81)
s.endUse(at: t2)
dump("forfeit at 60s+", s, at: t2)

let t3 = t2.addingTimeInterval(1.4)
s.beginUse(at: t3)
dump("unlock 1.4s after forfeit", s, at: t3.addingTimeInterval(0.2))

let t4 = t3.addingTimeInterval(70)
s.endUse(at: t4)
s.beginUse(at: t4.addingTimeInterval(70))
dump("after a full 70s away", s, at: t4.addingTimeInterval(70))

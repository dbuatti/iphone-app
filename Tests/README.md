# Tests

The state machine, checked.

PhoneFree's guard is the part of the app that is hardest to reason about and
easiest to break: a budget that is *spent* by use, *recharged* by being away,
and must not be refilled by a re-entry inside one sitting. None of that is
visible in a screenshot, and the simulator cannot reproduce a real lock or a
suspension — so the rules live here, in plain Swift, where they can be
checked in a second.

```
Tests/run.sh
```

Each harness is a standalone `main.swift`, compiled against the same
`Shared/PhoneFreeUsage.swift` and `Shared/PhoneFreeWindow.swift` the app
itself uses. There is no test framework and no mocking: the real state
machine, driven by hand-written dates.

A change that breaks a rule breaks a check here, and the check's name says
which rule.

## The suites

| Suite | What it pins |
| --- | --- |
| `guardbudget` | The guard as a budget: what spends it, what recharges it, and the traps that cost real hours to find — a re-entry inside one sitting must not refill it, a Face ID glance must not be able to record a stretch it never lost, and a session the app lost track of must not be charged for time the phone spent face-down. |
| `redhold` | The state the Lock Screen reads when the guard is spent and the phone was put down while the app was suspended — the "hold the red reading" fix, which depends on the state really being the guard-already-over state. |
| `devicetests` | The logic behind the device tests that can only be verified by eye: what the Lock Screen and the Dynamic Island will draw, and when. |
| `guarddump` | A tool, not a test. It prints the state machine's decisions for a scripted session, so a new rule can be *watched* as well as checked. |

## Why they are here rather than in a scratch directory

They were written in `/tmp`, which macOS is free to empty. The guard rules
are the ones most worth protecting, and a test that can be lost is not a
test.

## Running one suite

```
swiftc Tests/guardbudget/main.swift \
    Shared/PhoneFreeUsage.swift \
    Shared/PhoneFreeWindow.swift \
    -o /tmp/guardbudget && /tmp/guardbudget
```

Each check prints `PASS` or `FAIL` with a name, and the exit code is
non-zero if anything failed.

## Two things to know when adding a check

**Use a modern date.** `Calendar.current.isDate(_:inSameDayAs:)` is
unreliable for dates near the 1970 epoch — it puts two times on the same
afternoon in different days. The once-a-day guard refill depends on that
comparison, so the harnesses start from a date in the 2020s.

**Pass the "last seen" moment explicitly.** `settled` reads the live
`phoneFreeLastSeenAt` key when it is not given one, and the harnesses must
never touch the real shared container. Every call therefore passes the
moment it wants judged.

**`PhoneFreeUsage.diagnosticsEnabled` is `true`**, so the harnesses print
the state machine's own log lines as they go. That is useful — a failing
check is usually readable straight from the lines above it — but it means
the output is longer than the `PASS`/`FAIL` list. `run.sh` counts them
separately.

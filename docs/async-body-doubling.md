# Async body doubling — design

Body doubling is the reason the shared-session feature exists: another person
being *present* while you do the thing makes it easier to start and to keep
going. The mechanism is company and accountability. It is not surveillance, and
it is not a race.

The feature shipped today is live: two people in the same moment, over SharePlay
or a nearby code. That covers one shape of body doubling — "we're doing this
together, right now". It does not cover the other, more forgiving shape:

> *Cara did her twenty minutes this morning. I'm doing mine now.*

That second shape needs nothing live. It needs a record that outlives the
moment, and a place to put it. This document describes that version.

## What stays

Almost everything. The current shared-session code is already transport-agnostic:

- `SharedSessionState` (`Shared/PhoneFreeSharedSession.swift`) reduces wire
  messages into room state. It has no idea what carried them.
- `SharedSessionLink` (`Iphone app/PhoneFreeSharedLink.swift`) is the seam.
  `NearbySessionLink` and `SharePlaySessionLink` both implement it.
- `PhoneFreeSharedSessionView` renders the room; `PhoneFreeStore` wires the
  link and reduces messages.

The async version is therefore **a third `SharedSessionLink` implementation**,
not a rewrite. The room logic, the invite code, the participant model and the
UI all survive.

## What changes

### 1. Own counters only

`sharedFate` does not survive the move, and should not be offered async.

Shared fate means "if anyone picks up past their grace, the shared time ends for
all of them". That is a fair and legible promise when two people are watching
the same clock. Async, it becomes something else: Cara bails at 3pm, and you
find out at 8pm that a session you had already stopped thinking about is over.
Nobody witnessed it, nobody could have prevented it, and the punishment arrives
detached from its cause. That is exactly the mechanic this app exists to avoid.

So: **async rooms are always `.ownCounters`.** The mode picker is not shown in
the async flow. `SharedSessionMode` keeps both cases — the live flows still use
them — but an async room is constructed with `.ownCounters` and the engine
never sees `.sharedFate` there.

### 2. A commitment is not a session

A live room starts *now* and ends when someone ends it. An async room needs a
shape that can sit untouched for hours, because that is the normal case.

The unit becomes a **commitment**, with a bounded life:

| Field | Meaning |
| --- | --- |
| `anchor` | when the commitment opens (the starter's put-down) |
| `closesAt` | when it lapses if nothing is reported |
| `reportedAt` | set when this phone reports a finished stretch |
| `reportedSeconds` | the stretch that was reported |

A commitment that lapses is **not a failure**. It simply closes and stops
asking. This is the async expression of the app's existing rule: ending early is
still ending.

Suggested default life: **12 hours** — long enough to cover "I'll do it today",
short enough that yesterday's room does not greet you tomorrow.

### 3. Reports, not live status

Live rooms carry `.status(id:isOnPhone:at:)` and `.pickedUp(id:name:)`. Async
replaces the first with a report:

- `.reported(id:seconds:at:)` — "I finished a stretch of this long."
- `.pickedUp` is **dropped entirely** async. A pickup is not news worth carrying
  for six hours, and it has no consequence in own-counters mode anyway (the
  engine already ignores it there — see `SharedSessionState.receive`).

What the other person sees is therefore a small **feed of what was actually
done**, never a live "is currently on their phone" indicator. That distinction
matters: a live indicator invites checking, and checking is not body doubling.

### 4. Time has to be trustworthy

The live code says, correctly, that *"arrival order wins, because two phones'
clocks are never close enough to rank events between them."* Live, that is
fine — everything arrives within seconds.

Async, it breaks. A report that arrives six hours late cannot be ordered by
arrival, and `anchor`/`reportedAt` written by a device clock that is wrong by
ten minutes would corrupt the feed.

So async uses **server-assigned timestamps** (CloudKit record modification
dates) for anything the other person reads, and treats the local device clock
as display-only. This is a new rule and needs to be stated in the code where it
applies.

## Identity

`SharedParticipant.id` is currently stable per install, and explicitly *not* the
iCloud account — "two phones belonging to one person are two participants".

CloudKit inverts that assumption: the iCloud account **is** the transport. Two
consequences:

- **Cara must be signed into iCloud**, and the two of you must mutually share
  the CloudKit record. There is no anonymous async path.
- **The id must follow the person, not the install**, or one person with two
  devices appears as two participants in their own room. Use the CloudKit user
  record name as the async participant id.

This is a behaviour change, not just plumbing, so it belongs in the UI copy too:
the person is told the room is shared through their iCloud account.

## Sharing model

CloudKit **sharing** (`CKShare`) on one record per commitment:

- The starter creates the record and a share.
- The share is sent to Cara through the standard `UICloudSharingController`
  sheet — she gets an iCloud link she accepts.
- Both phones write to the same record; the feed is the record's contents.

The invite code is **not** the door async — iCloud sharing is. The code stays
for the nearby path, where it is the front door. Said plainly in the UI so the
two flows are never confused.

## What has to be built

| Piece | Notes |
| --- | --- |
| `CloudKitSessionLink` | third `SharedSessionLink`; same message API, different carriage |
| CloudKit container + `iCloud` capability | app target and widget target |
| `CKShare` + sharing sheet | the join flow |
| Participant identity | CloudKit user record name, replacing the per-install id async |
| Commitment lifetime | `closesAt`, lapse handling, "not a failure" copy |
| Report message + feed UI | replaces the live participant list async |
| Server-time discipline | one place, documented |
| Widget surface | optional: "Cara finished 30 min today" |
| Harness | reduce/ordering/lapse tests, as with the counter |

## What it costs

- **The paid Apple Developer Program ($99/yr).** CloudKit containers and
  CloudKit sharing are not available on a free/personal Apple ID. This is the
  same wall that made SharePlay untestable, re-entered deliberately because
  async is worth it and SharePlay was not.
- **The "no network at all" claim.** The app currently makes no outbound
  request. This adds one. The *privacy* claim survives — what travels is "Dan
  finished a 28-minute stretch", never usage data, never the counter, never
  which apps — but the wording has to change honestly.

## Open questions

1. **Does a report carry seconds, or just "done"?** Seconds is more rewarding
   and more honest; "done" is lower pressure and hides comparison. The
   non-punitive design leans toward **"done" by default, seconds optional**.
2. **One commitment at a time, or several?** Start with one room per pair.
3. **Does an async room appear on the Lock Screen?** Probably not — body
   doubling should not become another thing to check.
4. **Does anything expire server-side?** A commitment record could be deleted
   after it lapses, rather than kept as history.

## Suggested build order

1. Container + capability, and a record that round-trips between two devices
   (proves the transport before any feature rides on it).
2. `CloudKitSessionLink` with `hello`/`reported`/`end`/`bye` only.
3. Identity change: participant id from the CloudKit user record.
4. Commitment lifetime and lapse.
5. Feed UI, replacing the live participant list in the async flow.
6. Mode picker hidden in the async flow; `.ownCounters` enforced.
7. Widget surface, if wanted.

Steps 1–3 are the ones that cannot be skipped or reordered: without a
round-tripping record and a person-level identity, everything above them is
guesswork.

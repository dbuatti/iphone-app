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

A commitment that lapses is **not a failure**. It simply closes and stops
asking. This is the async expression of the app's existing rule: ending early is
still ending.

Suggested default life: **12 hours** — long enough to cover "I'll do it today",
short enough that yesterday's room does not greet you tomorrow.

### 3. Reports, not live status

Live rooms carry `.status(id:isOnPhone:at:)` and `.pickedUp(id:name:)`. Async
replaces the first with a report:

- `.reported(id:at:)` — "I did a stretch today." No number travels (see
  Decisions, 1).
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
| Harness | reduce/ordering/lapse tests, as with the counter |

## What it costs

- **The paid Apple Developer Program ($99/yr).** CloudKit containers and
  CloudKit sharing are not available on a free/personal Apple ID. This is the
  same wall that made SharePlay untestable, re-entered deliberately because
  async is worth it and SharePlay was not.
- **The "no network at all" claim.** The app currently makes no outbound
  request. This adds one. The *privacy* claim survives — what travels is "Dan
  did a stretch today", never a number, never usage data, never the counter,
  never which apps — but the wording has to change honestly.

## Decisions

### 1. A report says "done", not a number

A report carries **"I did a stretch today"** and nothing else. Seconds are not
sent.

The reason is the whole design of this app. A number invites comparison — *she
did 40, I did 12* — and comparison turns body doubling into a scoreboard, which
is the mechanic the app deliberately avoids everywhere else (no streak pressure,
no punishment, one action at a time). A second person's number also becomes a
target, and a target you did not choose is a demand.

If a number is ever wanted, it should be the sender's *own* history shown to
themselves on the Progress tab — never what crosses the wire.

This also simplifies the message: `.reported(id:at:)`, no seconds.

### 2. One commitment per pair, at a time

A room holds one commitment. Starting another replaces the first, or waits
until it lapses.

Several open commitments would mean a list to manage, and a list is a chore. The
feature's promise is "one small thing you and one other person are doing" —
anything that needs triaging has already failed.

More than two people is a separate question and not answered here.

### 3. No Lock Screen surface for async rooms

The async room does **not** appear on the Lock Screen, on the widget, or in the
Live Activity. (It does not today either — the widget carries no shared state —
so this is a decision not to add it, not work to remove it.)

The Lock Screen is the app's most precious surface: it is where the away counter
lives, and it is deliberately quiet. A second person's commitment there would
turn body doubling into another thing to check each time you pick up the phone.
That is the opposite of what it is for.

The async room lives **inside the app only**, on the sheet you deliberately
open.

### 4. A lapsed commitment is deleted, not archived

Nothing is kept server-side once a commitment lapses or ends. The CloudKit
record is deleted; the local room is cleared.

Keeping history would make the feature into a record to consult — *did she do
it last Tuesday?* — which is tracking, and tracking is not body doubling. It
also keeps the "we store nothing about you" claim true for the only server the
app has.

The one thing worth keeping is the *pairing itself* (who you double with), so
you do not have to re-share an iCloud link every time. The pairing is a fact
about the relationship; the commitments are not worth keeping.

## Suggested build order

1. Container + capability, and a record that round-trips between two devices
   (proves the transport before any feature rides on it).
2. `CloudKitSessionLink` with `hello`/`reported`/`end`/`bye` only.
3. Identity change: participant id from the CloudKit user record.
4. Commitment lifetime and lapse.
5. Feed UI, replacing the live participant list in the async flow.
6. Mode picker hidden in the async flow; `.ownCounters` enforced.

Steps 1–3 are the ones that cannot be skipped or reordered: without a
round-tripping record and a person-level identity, everything above them is
guesswork.

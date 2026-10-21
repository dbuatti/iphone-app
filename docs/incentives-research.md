# Incentives beyond the counter — research

The away counter is a **self-monitoring** device, and the evidence is that
self-monitoring alone is the weakest lever available. Tracking reliably improves
*awareness* and only inconsistently converts to *less use* (Zimmermann, 2021:
tracking apps raise digital self-awareness but are "less likely to lead to a
reduction").

So the question — *a counting timer is good, but surely there's more?* — has a
real answer, and the strongest parts of it are not "add a streak."

This document is research, not a plan. It records what the surfaces can do,
what the behaviour evidence actually supports, what shipped apps do, and where
a mechanic would betray the app's non-punitive ethos.

## The constraint that shapes everything

A Live Activity visible on the Lock Screen or Dynamic Island **cannot be updated
by the app while it is backgrounded.** Only three things can change what it
shows:

1. **APNs push** — the app's only background path.
2. **A foreground update**, while the app is open.
3. **System self-updating views** — `Text(style: .timer)`,
   `ProgressView(timerInterval:)`. These tick with no push at all, because the
   system animates them.

That third one is why the away counter already counts while suspended. **Any
live mechanic that changes meaningfully over time must ride on a self-updating
view, or on a push.** This is the difference between an idea that works and one
that looks broken.

Two more hard facts:

- **A Live Activity lives at most 8 hours** (12 on the Lock Screen, counting
  stale). Apple's own guidance is "15 to 30 minutes is adequate." **The away
  counter is a multi-day metric, so the accessory widget — which persists on a
  WidgetKit timeline — is the real long-horizon surface, not the Live Activity.**
- **Buttons on a locked Lock Screen are inert** until the user unlocks. So a
  "tap to claim" still costs an unlock. Interactive Live Activities run an App
  Intent in the extension; the app does not launch.

Push budget, in practice: **priority 5 is unmetered** (opportunistic delivery),
**priority 10 is metered** (iOS decides the budget; exceed it and updates are
dropped). `NSSupportsLiveActivitiesFrequentUpdates` raises the metered budget,
and a user who turns off "frequent updates" **ends every running activity**.

## Dynamic Island and widget space

| Surface | Room | Fits |
| --- | --- | --- |
| Dynamic Island compact | ~one glyph + one short number, 28pt circle when narrow | presence, a single atom |
| Dynamic Island minimal | one glyph | presence only |
| Dynamic Island expanded | leading / trailing / center / bottom | a sentence, a ring, 1–2 buttons |
| `accessoryCircular` | one ring or glyph | one metric |
| `accessoryRectangular` | title + 1–2 lines | a sentence + tiny chart |
| `accessoryInline` | **one line, no colour** | a single sentence |

**Colour is the interesting catch.** On the Lock Screen, accessory *widgets*
tend to render monochrome/vibrant, tinted by the wallpaper — so a "turn red"
signal in a widget is often flattened to luminance. **A Live Activity is the
only place semantic colour survives reliably** (`activityBackgroundTint`,
`keylineTint`, `.tint()`).

Sound and haptics come only from a push alert's payload. You can therefore make
a noise, but not control it finely — silent mode may still produce a haptic.

## What the evidence supports

| Mechanic | Evidence | Fit |
| --- | --- | --- |
| Self-monitoring | Awareness yes, behaviour weak | already doing it |
| Interruption / friction at open | **Strong.** *one sec* (PNAS 2023): 36% of opens abandoned, 57% fewer openings after 6 weeks. The **dismiss option** was the strongest part | can't intercept launches; the *principle* applies in-app |
| Self-set commitments | **Moderate–strong, conditional.** App limits cut use ~33%, **but only for people over their own ideal** (Hoong, 2021) | favours *user-chosen* goals |
| Nudge bundles (monitor + goal + prompt) | Moderate | multi-signal beats one number |
| Grayscale | Repeatedly effective; acceptability is the problem | offer, never impose |
| Streaks / loss aversion | Real effect, but rigid streaks raise **abandonment** after a break | **conflicts with the ethos** |
| Body doubling / co-presence | Supported in ADHD/focus literature | opt-in presence, never ranking |

Honest caveats: streak efficacy is mostly app telemetry and confounded; nudges
**habituate** (users report the same intervention feeling meaningful on day one
and "an annoying formality by week four"); and reactance is real — some RCTs
find *higher negative affect* in nudged groups.

## What shipped apps do, and what it cost them

- **one sec** — deliberate interruption with an easy "dismiss". 57% fewer
  openings. Complaints: intervention fatigue by ~week 4; the pause becomes a
  formality.
- **Opal** — hard blocks, scores, streaks, "no way out" positioning. Strong
  testimonials, but the loudest criticism is exactly the punitive framing: it
  "treats the symptom" and feels like being trapped.
- **ScreenZen** — pre-open delay plus a **streak on *adhering to limits*** (not
  on usage). Loved, free. Note the framing: the streak is a thing you *keep by
  your own choice*, not a countdown you lose.
- **Unpluq / Brick** — physical friction. Users report large reductions and
  praise that it "doesn't block completely, just makes you wait." The wait, not
  the wall, is the active ingredient.
- **Forest** — gamified, but a dying tree becomes a **guilt reminder**;
  all-or-nothing.
- **iOS Screen Time** — grayscale has the best evidence; limits work only for
  over-users; "ignore limit" is trivially easy.

**Cross-cutting lessons.** The winners make the automatic act *conscious* and
offer an easy *no*. Streaks motivate when framed as adherence you control, and
demoralise when framed as all-or-nothing loss. Punitive mechanics drive
engagement and attract the angriest reviews. And **nobody has claimed the
persistent Lock Screen as an incentive surface** — most apps interrupt you when
you are *already opening* something. A Live Activity is visible *before* you
decide, which is the gap worth filling.

## Ideas ranked by feasibility

**Tier A — works today, no entitlement, mostly free**

1. **Reframe cost as gain.** The primary number becomes *earned time back*
   ("2h 47m returned today") rather than a bare count-up. No new mechanics; it
   strengthens the weakest lever by adding meaning. Self-rendering.
2. **A personal-goal progress ring, not a streak.** A `ProgressView` filling
   toward a *user-chosen* away-time goal. Completing it is the reward; breaking
   it costs nothing. This is the commitment evidence applied without loss
   aversion.
3. **The guard, reframed as a breath.** Your grace window as a system timer is
   "a breath before you go back", not a tripwire. Costs nothing; changes the
   reading entirely.
4. **Two App-Intent buttons in the expanded view** — "I'm back" / "Start a
   20-min pause". Ports *one sec*'s dismiss-or-continue into a calm register.
   Post-unlock only.
5. **One celebration channel.** A single high-priority push alert at a genuine
   personal best. One alert, occasional, earned — never random, never recurring.

**Tier B — needs a server (push) and design care**

6. Earned, calm reveals while away (never variable-ratio loot).
7. An opt-in "why I'm doing this" echo, shown verbatim.
8. An opt-in, gentle co-presence signal ("Alex is away too") — a boolean, not a
   leaderboard.
9. Recovery-first language after a lapse ("You're 100% away again — that's the
   reset, not a loss").

**Tier C — possible, but tighten the ethos or need entitlement**

10. A soft grayscale/dim mode the Live Activity *announces* and a Control
    toggles. Needs the app to apply it.
11. Apple Watch Smart Stack presence (`.supplementalActivityFamilies([.small])`)
    — the wrist is the surface most likely to interrupt a reach.
12. An "unlocks used today: 1 of 3" ambient budget. Effective; drifts punitive.

## Where this would betray the app

- **Loss-framed streaks.** Breaking a rigid streak triggers the
  abstinence-violation effect: all-or-nothing abandoners quit entirely. A ring
  going *full to empty*, or a "streak lost" label, is the guilt machine the app
  exists to avoid.
- **Red as failure.** The current red-on-overrun is a punishment signal.
  Amber/neutral plus a question ("you've been here a while — still want to be?")
  informs without accusing.
- **Artificial scarcity and deceptive urgency** — documented dark patterns.
  Reject.
- **Variable-ratio rewards** maximise compulsion, which is the opposite of a
  tool the user *leaves*.
- **Leaderboards.** Co-presence helps; ranking willpower shames. Presence only.
- **The presence-equals-nag trap.** A Live Activity shown *while the user is
  already on the phone* competes with the thing you want them to put down, and
  reads as a scold. Prefer surfaces seen when the phone is *down*.
- **The self-monitoring illusion.** If PhoneFree only becomes a prettier
  counter, it will be pretty and ineffective.

**The test to apply to every idea:** *If this fired while the user was already
having a bad day, would it feel like support or like a teacher with a red pen?*

## Top five

1. **Reframe the counter from cost to gain** — *earned time back*, not a bare
   count-up. Free, and it strengthens the weakest lever.
2. **A personal-goal ring, never a streak** — completion is the reward,
   breaking costs nothing.
3. **Two App-Intent buttons in the expanded view** — "I'm back" / "Start a
   pause", the calm version of the proven dismiss-or-continue reflex.
4. **Exactly one celebration channel** — a single push at a genuine personal
   best, never random, never recurring.
5. **Design for the phone-down surface, and make recovery instant** — durable
   metric in accessory widgets, meaningful moments on Lock Screen / StandBy /
   Watch, and no red-failure or streak-loss state anywhere.

## Sources

**Apple**
- Displaying live data with Live Activities —
  <https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities>
- ActivityKit push notifications —
  <https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications>
- Live Activities HIG —
  <https://developer.apple.com/design/human-interface-guidelines/live-activities>
- Interactivity in widgets and Live Activities —
  <https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities>
- Supporting additional widget sizes —
  <https://developer.apple.com/documentation/widgetkit/supporting-additional-widget-sizes>
- WWDC23 10184 / 10185 / 10194, WWDC24 10068, WWDC26 223

**Behaviour**
- *one sec* field experiment, PNAS —
  <https://pmc.ncbi.nlm.nih.gov/articles/PMC9974409/>
- Hoong (2021), soft commitment devices —
  <https://www.sciencedirect.com/science/article/abs/pii/S0014292121002269>
- Nudge RCT — <https://pmc.ncbi.nlm.nih.gov/articles/PMC9112639/>
- Multi-method app study — <https://pmc.ncbi.nlm.nih.gov/articles/PMC10498313/>
- Zimmermann (2021) — <https://www.journals.uchicago.edu/doi/10.1086/714365>
- Screen time & mental health, BMC Medicine 2025 —
  <https://link.springer.com/article/10.1186/s12916-025-03944-z>

**Apps**
- one sec — <https://one-sec.app/>
- Opal — <https://www.opal.so/>
- ScreenZen — <https://screenzen.co/>
- Unpluq — <https://www.unpluq.com/>
- Forest — <https://forestapp.cc/>

## One thing to verify rather than assume

How PhoneFree detects "in use" and "away" decides what is even possible here.
iOS does not expose a reliable "screen is on" signal to third-party apps without
entitlements, and the current implementation infers use from lock/unlock and
scene transitions — which is precisely where the sleep bugs live. Any incentive
built on a signal that misfires during sleep will misfire with it. **Fix the
signal before building on it.**

# Family Controls entitlement — request draft

Everything below is text you can paste into the form at
<https://developer.apple.com/contact/request/family-controls-distribution>.

You need the **paid** Apple Developer Program membership before this form is
available to you, and the request is reviewed by a human at Apple. Approval is
not guaranteed — Apple mostly grants this entitlement to parental-control and
digital-wellbeing apps.

The app works fully without it. This only unlocks the last piece (blocking
other apps during a goal).

---

## Identity

| Field | Value |
| --- | --- |
| App name | PhoneFree |
| Bundle ID | `com.danielebuattipersonalteam.Iphoneapp` |
| Team ID | `6SPV96FZW9` |
| Category | Health & Fitness (secondary: Productivity) |

## Frameworks requested

- `FamilyControls` — to ask the user for authorization
- `DeviceActivity` — to monitor pickup counts and app usage on the user's own device
- `ManagedSettings` — to shield distracting apps for the duration of a phone-free goal

## What the app does

PhoneFree helps one person reduce how much they use their own phone.

The app has a single number at its centre: how long it has been since the user
last picked their phone up. The user sets a phone-free goal (for example twenty
minutes), puts the phone down, and the app keeps a countdown on the Lock Screen.
If they pick the phone up mid-goal, the app asks them to confirm before ending
it early — deliberately, with a hold and a short wait — rather than simply
ending it. When the goal ends, the app asks a couple of questions about how the
time felt and uses those answers to suggest better things to do next time.

## How each framework would be used

**FamilyControls** — `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
Only the `.individual` case is used. This is a self-management app: the person
requesting authorization is the device owner and the only person whose activity
is ever monitored. There is no parent/child, family, or multi-user mode.

**DeviceActivity** — to show the user their own honest numbers instead of the
proxy the app uses today. The app currently counts its own activations as a
stand-in for pickups, and tells the user that is what it is doing. With
`DeviceActivityData` (`firstPickup`, `totalPickupsWithoutApplicationActivity`,
`ApplicationActivity.numberOfPickups`) the app could show real pickup counts and
which categories of app actually pull at them. A `DeviceActivityMonitor`
extension would also let the app notice the end of a monitoring interval to
refresh the Lock Screen counter.

**ManagedSettings** — during an active phone-free goal, apply a
`ManagedSettingsStore` shield to a user-chosen set of apps and categories for
that goal's duration only, then remove it. The user picks the apps; the app
never picks for them, and the shield lifts automatically when the goal ends or
is ended early. This is the "phone-free" half of the promise that the app
currently cannot keep.

## Data handling

All data stays on the device, in an App Group shared with the app's own widget
extension. There is no server, no account, and no analytics. The app does not
transmit usage data, does not sync it to iCloud, and does not share it with
anyone. The only outbound network request the app makes is none at all.

## Who it is for

PhoneFree is built specifically for people with ADHD and OCD. For that audience
the design deliberately avoids the mechanics that make habit apps harmful:
there is one action at a time, no punishment for a broken streak, and no
ambiguous icon-only controls. Screen Time shielding matters especially here —
willpower-based approaches are exactly what does not work for these users, and
a short, bounded, automatically-lifting block is what makes a phone-free
stretch survivable.

## Why the entitlement is needed rather than Screen Time usage descriptions

Apple restricts these frameworks because they are powerful. Using them for
self-management only, with `.individual` authorization, no family sharing, no
data collection, and a shield that always lifts on its own, is the narrowest
possible use of that power. Without the entitlement the app can only ask the
user politely.

---

## What happens once it is granted

1. Add the `Family Controls` capability to both the app and the widget target.
2. Add a `DeviceActivityMonitor` extension target.
3. Ask for `.individual` authorization from Settings inside the app.
4. Store the user's chosen apps/categories as a `FamilyActivitySelection` and
   apply a shield for the goal's duration.
5. Replace the activation-count proxy on the Progress tab with real pickup
   data, and label it as coming from Screen Time.

Nothing here changes the app's architecture; it slots into the goal lifecycle
that already exists (`startGoal`, `finishExpiredGoalIfNeeded`, `breakPromise`).

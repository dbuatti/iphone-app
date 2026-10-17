# Screen Time version — plan for later

The app today notices phone use in two ways: PhoneFree being open, and the
Shortcuts automations the user points at their distracting apps
(`StartPhoneUseIntent` / `StopPhoneUseIntent`). Both feed the same shared clock,
`Shared/PhoneFreeUsage.swift`: use freezes the counter, and use past the grace
period (60 s by default) resets it.

The Screen Time frameworks replace the guesswork with real signals and a real
block. The clock does not change. Only what feeds it changes.

## Prerequisite

- Paid Apple Developer Program membership. A personal team cannot add the
  Family Controls capability at all.
- Development builds then work on your own device straight away. The
  distribution entitlement (App Store / TestFlight) needs Apple's approval:
  see `family-controls-request.md`.

## Steps

1. **Capability + authorization.** Add Family Controls to the app target. In
   Settings, replace the Shortcuts setup card with "Choose apps to watch". This
   calls `AuthorizationCenter.shared.requestAuthorization(for: .individual)` and
   then shows a `FamilyActivityPicker`. Store the `FamilyActivitySelection` in
   the app group.

2. **Use detection: `DeviceActivityMonitor` extension (new target).**
   Monitor an all-day schedule with a `DeviceActivityEvent` on the chosen
   apps/categories. Give it a threshold equal to the grace period (`resetAfter`).
   - `eventDidReachThreshold`: the user has been on those apps for the whole
     grace period, so reset: `PhoneFreeUsage.State.restart(at:)` and set
     `usingSince` so the counter holds at zero.
   - The extension cannot see "app opened" instantly. Pair it with step 3,
     which can.

3. **Interrupt on open: Shield.** Apply a `ManagedSettingsStore` shield to the
   selection **all the time**, not only during goals. Add two extensions:
   - `ShieldConfigurationDataSource` draws the PhoneFree screen: "You've been
     away 1:23:45. Open anyway? Your timer resets in 60 s." This is the
     interrupt-on-unlock the Shortcuts version can't do.
   - `ShieldActionDelegate`: "Put it down" closes the app. "Open anyway"
     lifts the shield for that app for a short window, calls
     `beginUse(at:)` in the shared clock and schedules the existing
     `PhoneFreeUseReminders`. Re-shield when the window ends, using a
     `DeviceActivity` schedule of the same length.

4. **During a goal.** Keep the shield on and drop the "Open anyway" button.
   Ending the goal still goes through the promise gate in the app.

5. **Real pickups.** A `DeviceActivityReport` extension shows real pickup
   counts on the Progress tab, replacing the "app opened" proxy, and labels
   them as coming from Screen Time.

6. **Retire the Shortcuts path.** Keep the intents for people who never grant
   Screen Time access, but hide the setup card once authorization is approved.

## What stays the same

`PhoneFreeUsage` (freeze → grace → reset), the in-app banner, the widget's
paused/reset states, the 15 s reminders and the goal nudges all work unchanged.
They don't care where the "using / put down" signal comes from.

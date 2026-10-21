# Capturing screenshots of PhoneFree

How to produce images of the app to show people. This is written for casual
sharing — texting a friend, dropping one in a chat, putting a few in a note. If
these are ever headed for the App Store, the rules change and this document
would need a section on required sizes and metadata; right now it does not.

## The one thing that decides everything

**The simulator and your iPhone show different app.** This is not a small
difference, so it goes first.

The simulator can show you:

- The away counter inside the app
- The guard banner, the progress bar, the hero number
- Settings, Onboarding, Progress, the shared-session sheet

The simulator **cannot** show you:

- The **Lock Screen** counter (there is no real lock screen to draw on)
- The **Dynamic Island** (the simulator has no island host for this)
- The **accessory widget** on the Lock Screen
- Real suspension — the app keeps running in the simulator, so anything that
  depends on the app being *suspended* (the guard behaving correctly across a
  lock) will not reproduce

So: **if the image you want is "the counter on the Lock Screen", you must use
the physical iPhone.** There is no way around this. Trying to force it in the
simulator is the most common wasted hour here.

Everything else — the app itself — is far easier and cleaner from the simulator.

## Path A — the simulator (fast, repeatable, most images)

Best for: anything *inside* the app. The away counter, the guard banner, the
settings, the progress view.

### One-time setup

1. Open the project in Xcode: `Iphone app.xcodeproj`.
2. Pick a destination — the scripts below use **iPhone 18 Pro**, id
   `BC45F985-0729-4BBF-81D7-E30F4A0CA687`.
3. Boot it once so the home screen is ready:

   ```sh
   xcrun simctl boot BC45F985-0729-4BBF-81D7-E30F4A0CA687
   open -a Simulator
   ```

### Build and install

```sh
cd "/Users/danielebuatti/Documents/Iphone app"
xcodebuild -scheme "Iphone app" -configuration Debug \
  -destination 'platform=iOS Simulator,id=BC45F985-0729-4BBF-81D7-E30F4A0CA687' \
  build
```

Then install and launch:

```sh
xcrun simctl install BC45F985-0729-4BBF-81D7-E30F4A0CA687 \
  "$(find ~/Library/Developer/Xcode/DerivedData -name 'Iphone app.app' -path '*Debug-iphonesimulator*' | head -1)"
xcrun simctl launch BC45F985-0729-4BBF-81D7-E30F4A0CA687 \
  com.danielebuattipersonalteam.Iphoneapp
```

### Get the app into the state you want

This is the fiddly part, and it is what makes the difference between a good
image and a confusing one. The counter reflects **real elapsed time**, so you
often want to fake it.

- **Away counter, looking good** — clear all data from Settings, then leave the
  app. Wait, or push the clock: choose **Features → Location**… no. Use
  **Simulator → Device → Restart** only if needed; the honest way is to wait,
  or to set the *host Mac's* clock forward temporarily. Waiting is simpler and
  less likely to confuse you later.
- **Red / past-guard state** — stay in the app until the guard window ends.
  This is slow with the default guard. For a screenshot, temporarily lower the
  guard length in Settings to its shortest value, reach red quickly, *then*
  restore the setting before you build the image you keep.
- **Guard banner holding** — pick up, and shoot in the first seconds while the
  number is still held.

> Changing a setting and restoring it afterwards is fine for a screenshot. It is
> not fine if you forget to restore it and then wonder why the app behaves
> differently tomorrow.

### Take the shot

**The best way is the Simulator's own camera button** — the toolbar item, or
**File → Save Screen**. It captures at full device resolution, cleanly, with no
status-bar junk from your Mac.

From the command line:

```sh
xcrun simctl io BC45F985-0729-4BBF-81D7-E30F4A0CA687 screenshot \
  ~/Desktop/phonefree-away.png
```

### Optional: a clean status bar

Apple's own screenshots never show 3% battery or 4:20am. You can do the same:

```sh
xcrun simctl status_bar BC45F985-0729-4BBF-81D7-E30F4A0CA687 override \
  --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
```

Undo it when you are done, or every later screenshot inherits it:

```sh
xcrun simctl status_bar BC45F985-0729-4BBF-81D7-E30F4A0CA687 clear
```

## Path B — the physical iPhone (the only way to see the Lock Screen)

Best for: the Lock Screen counter, the accessory widget, the Dynamic Island —
the surfaces that *are* the app's promise, and the ones people actually react to.

1. Connect the iPhone. In Xcode, pick it as the destination.
2. Build and run (**Cmd-R**). First run may require trusting the developer
   certificate: **Settings → General → VPN & Device Management → trust**.
3. Get the app into the state you want (see the note above about shortening the
   guard temporarily).
4. **Lock the phone** and look at the Lock Screen.
5. Take the shot:
   - **Side + Volume Up** — the normal iPhone screenshot.
   - **Dynamic Island** — screenshot while unlocked with another app open.
   - **Accessory widget** — add the PhoneFree accessory to the Lock Screen
     first (long-press the Lock Screen → Customize → add widget).
6. The images land in Photos; AirDrop or sync them to your Mac.

Physical-device screenshots have your real status bar, real carrier, real
battery. That is fine for showing a friend. If you ever want them for anything
public, crop or overlay a clean bar.

## What is worth photographing

For showing people, these tell the story best, roughly in order:

1. **The Lock Screen counter** — this is the "oh" moment. The app's whole idea
   is a number you see without unlocking. Physical device only.
2. **The guard banner holding** — inside the app, just after a pickup, showing
   the stretch being protected. Simulator is fine.
3. **Past the guard, in red** — the honest one. Shows the app is not pretending.
4. **The Dynamic Island** — proves it works over other apps. Physical only.
5. **Progress / stats** — the long view.
6. **The shared-session sheet** — if you are showing the body-doubling idea.

Three or four good ones beat ten average ones. The Lock Screen is the one that
makes people understand.

## Honest limits of this document

- **No image is included, and none was generated.** I cannot render the app's UI
  or produce images. Everything here produces images *you* take on your machine.
- **The simulator cannot show the Lock Screen.** Repeating it because it is the
  single most common source of wasted time.
- **The state is real time.** There is no clean "set the counter to 4:28"
  button, and inventing one would be a feature, not a screenshot trick. Plan to
  wait, or change the guard length temporarily and restore it.
- **These are not App Store screenshots.** Different rules, different sizes.
  If that day comes, this document needs a second section, not a tweak.

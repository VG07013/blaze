# Blaze 🔥

A workout streak tracker built around daily quests and **Blaze**, a phoenix who
reacts emotionally to your streak. Keep the fire alive: complete at least one of
three daily quests and Blaze grows brighter and stronger. Slip, and he gets
worried, freezes into an ash cocoon, or burns out — until you bring him back.

Everything is local and on-device. No backend, no accounts, no real-money
purchases.

## Requirements

- Xcode 16 or newer (the project uses file-system-synchronized groups)
- iOS 17.0+ deployment target
- A paid or free Apple developer team for HealthKit / App Group signing

## Getting started

1. Open `Blaze.xcodeproj` in Xcode.
2. Select the **Blaze** target → Signing & Capabilities → choose your team.
   Do the same for **BlazeWidgetExtension**.
3. If your team can't use the default identifiers, change the bundle IDs
   (`com.blaze.app`, `com.blaze.app.BlazeWidget`) and the App Group
   (`group.com.blaze.app`) — the group ID also lives in
   `Shared/BlazeCore.swift` (`BlazeAppGroup.identifier`) and both
   `.entitlements` files.
4. Build and run on a device for the full experience (HealthKit, haptics,
   Live Activities). The simulator works too; Health-verified quests then rely
   on the manual fallback.

## What's inside

| Piece | Where | Notes |
| --- | --- | --- |
| App target | `Blaze/` | SwiftUI, SwiftData persistence, iOS 17+ |
| Widget + Live Activity | `BlazeWidget/` | Small/medium home-screen widget, stretch-timer Live Activity |
| Shared code | `Shared/` | Design system, Blaze avatar rendering, widget snapshot, activity attributes |
| Asset generators | `Tools/` | Pure-stdlib Python scripts that produced the app icons and sound set |

### The loop

- Three daily quests (movement / strength / stretch / wildcard), generated at
  midnight from a weighted pool. The excluded quest type rotates and metrics
  vary so no quest repeats two days running. Difficulty adapts to fitness level
  and the last week's completion rate.
- Any 1 quest keeps the streak alive; all 3 is a perfect day (bonus embers, XP,
  and a chance at a streak freeze — better odds when quests were
  HealthKit-verified).
- Streak freezes (max 3) auto-apply at midnight on a missed day. No freeze
  means burnout: streak to zero, Blaze collapses to embers, and one quest
  revives him with a rise-from-the-ashes moment.
- Milestones at 7/30/100/365 days: full-screen celebration, tier evolution
  (Spark → Ember → Flame → Inferno → Eternal), exclusive cosmetics, and app
  icons.

### Feature map

- **HealthKit** (`Blaze/Services/HealthKitService.swift`) — read-only steps,
  active energy, exercise minutes, flights climbed, mindful minutes; movement
  and wildcard quests complete themselves.
- **Streak engine** (`Blaze/Services/BlazeEngine.swift`) — rollover settlement,
  freeze/burnout logic, rewards, celebrations, cosmetics unlocks.
- **Notifications** (`Blaze/Services/NotificationService.swift`) — morning /
  midday / evening / last-chance / freeze / burnout / milestone / comeback, all
  in Blaze's voice, per-category toggles, quiet hours, self-capping.
- **Widget** (`BlazeWidget/BlazeWidget.swift`) — Blaze's current form and mood,
  streak count, today's quest ring; re-renders at 6 pm and midnight so his
  expression stays honest without the app running.
- **Live Activity** (`BlazeWidget/StretchLiveActivity.swift`) — lock-screen and
  Dynamic Island countdown for the guided stretch.
- **Haptics & sound** — Core Haptics celebration patterns; procedural WAV set
  that respects the silent switch. Freeze and burnout are deliberately silent
  on the haptics side.
- **Cosmetics** — flame colors, plumage skins, app themes, and alternate app
  icons. Commons cost embers; rare/milestone items are earn-only.

### Regenerating assets

```sh
python3 Tools/generate_icons.py    # app icon PNGs (pure-stdlib PNG writer)
python3 Tools/generate_sounds.py   # procedural WAV sound set
```

Both scripts are deterministic and depend only on the Python standard library.

<div align="center">

# Aware

**A free, map-first personal safety app.**

![Platform](https://img.shields.io/badge/iOS%2017%2B-black?style=flat-square)
![Language](https://img.shields.io/badge/Swift%206.0-orange?style=flat-square&logo=swift)
[![License](https://img.shields.io/badge/license-CLL%20v1.2-blue?style=flat-square)](LICENSE.md)
![Status](https://img.shields.io/badge/status-alpha-yellow?style=flat-square)

![Free forever](https://img.shields.io/badge/free%20forever-✓-22c55e?style=flat-square)
![No accounts](https://img.shields.io/badge/no%20accounts-✓-22c55e?style=flat-square)
![Privacy-first](https://img.shields.io/badge/privacy--first-✓-22c55e?style=flat-square)

</div>

Aware is about staying aware before anything goes wrong, not just reacting once it has.
It gives you a safety map, safer walking routes, live location sharing with people you
trust, a one-tap SOS, a check-in timer, and emergency medical info that lives on your
phone. Every protective feature is free. No subscriptions, no accounts, no server holding
your location.

## What's in it

- **Safety map.** Nearby police, hospitals, fire, pharmacies, transport, taxis and
  24-hour spots, pulled live from MapKit as you pan. Toggle a crime heatmap on top.
- **Safer routes.** Long-press anywhere on the map to walk there, or type a destination
  in the Routes tab. With crime data loaded and "prefer safer routes" on, Aware picks the
  route past the fewest reported crimes instead of the fastest one, and tells you why.
- **Crime data.** Pluggable open-data backends, no API key needed. Queried over whatever
  you're looking at so it fills the screen. Working regions right now: UK (police.uk),
  Chicago, New York, San Francisco, Los Angeles.
- **SOS and live sharing.** Fires a pre-filled SMS to your alert contacts with a tappable
  Apple Maps link to where you are. No account, no backend.
- **Check-in timer.** Set a deadline, get on with your day. It survives a relaunch and
  schedules a local notification that goes off if the clock runs out before you tap
  "I'm safe". Miss it and Aware nudges you to alert your contacts.
- **Trusted contacts.** A local roster with per-contact alert opt-in. Import straight from
  your address book.
- **Emergency profile.** Blood type, allergies, conditions, medications, notes. Stays on
  the device.
- **Live Activity.** An active SOS, live-share or timer shows on the lock screen and in the
  Dynamic Island, countdown and all.

## Build

You'll need **Xcode 16+** with the **iOS 17+ platform** installed (Xcode → Settings →
Components), plus `xcodegen` (`brew install xcodegen`).

Aware depends on **[iUX-ios](../iUX-ios)**, the shared iOS design system, via a local path.
Check it out as a sibling directory first:

```
Projects/anti-ltd/
├── Aware-iOS/   ← this repo
└── iUX-ios/     ← shared iOS design system
```

Then:

```bash
make icon      # render the app icon from Tools/RenderAppIcon.swift
make project   # regenerate Aware.xcodeproj from project.yml (needs xcodegen)
make build     # xcodebuild for the iOS Simulator
make run       # boot the sim, install, launch
make device    # build, sign, install on the paired iPhone
make clean     # remove build/ and Aware.xcodeproj
make help      # list every target
```

The `.xcodeproj` is generated from `project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen) and is gitignored. **`project.yml` is the
source of truth**, so don't hand-edit the generated `.xcodeproj`.

## Running on your iPhone

```bash
make device          # build, install, launch on the paired phone
make device-install  # build + install (no launch)
make device-launch   # re-launch what's already installed
```

`make device` wraps `xcrun devicectl`. Before the first run, cable the iPhone, unlock it
and accept **"Trust This Computer"**, then run `xcrun devicectl list devices` to confirm
it's paired. If more than one phone is connected, point at the right one with `DEVICE=<udid>`
or `DEVICE_NAME="My iPhone"`.

## Layout

```
Sources/Aware/
├── AwareApp.swift          @main entry point
├── AppModel.swift          observable runtime + persisted state
├── AppSettings.swift       persisted user preferences
├── Location/
│   ├── LocationManager.swift        CLLocationManager wrapper (MainActor)
│   ├── PlaceSearch.swift            nearby-service MapKit search
│   ├── RoutePlanner.swift           safer-route picking
│   ├── EmergencyServices.swift      SOS / live-share SMS alerts
│   ├── NotificationScheduler.swift  check-in timer notifications
│   └── LiveActivityController.swift lock-screen / Dynamic Island session
├── Data/
│   └── CrimeService.swift           open-data crime backends
├── Models/
│   ├── TrustedContact.swift
│   ├── EmergencyProfile.swift
│   ├── AlertMessage.swift
│   └── SafetySession.swift          safety state machine + check-in reasons
└── UI/
    ├── RootView.swift          tab shell (map-first)
    ├── SafetyMapView.swift     interactive safety map + category filter
    ├── RoutesView.swift        safer route planning
    ├── SafetyView.swift        SOS, live sharing, check-in timer
    ├── ContactsView.swift      trusted-contacts roster
    ├── ProfileView.swift       emergency medical info + preferences
    └── OnboardingView.swift    first-run intro + permission priming
```

The UI is built on **iUXiOS**, the shared glass surfaces, settings cards, ambient backdrops
and Glance components, so Aware looks like the rest of the family.

`Tools/RenderAppIcon.swift` is a standalone Swift script that draws the app icon (a glossy
white disc with a checkmark-shield on a calm teal field) into `Resources/Assets.xcassets`.
Run it with `make icon`.

## Status

Alpha. The map, routing, crime data, SOS, timer, contacts and Live Activity all work.
Still on the list for a later pass: richer route weighting (lighting, population and
time-of-day on top of the current crime-proximity plus walking time).

See [CHANGELOG.md](CHANGELOG.md) for the full history.

## License

Aware is source-available under the **Counter-Limitation License (CLL) v1.2**. See
[LICENSE.md](LICENSE.md).

© 2026 Anti Limited.

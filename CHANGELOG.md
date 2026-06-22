# Changelog

All notable changes to Aware are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this file is baked
into the app at build time (`make changelog`) and shown under
Profile → About → Changelog.

## [0.1.0] - Unreleased

First scaffold of the map-first personal-safety app.

### Added

- **Settings tab**, styled like the flagship Clink settings: a square-tile
  "General" grid (Permissions, Data sources, Changelog) over signature
  glyph-headed sections (Routes & map, Safety, Privacy, Not-an-emergency,
  About). All app preferences moved here off Profile — the Profile tab now holds
  only the emergency medical card. (`SettingsView`)
- Profile → About → Data sources: an honest, per-source breakdown of where the
  app's data comes from (open-data crime feeds, Apple MapKit, and on-device-only
  personal data).
- Crime heatmap now covers Maryland's population core: Baltimore City (Open
  Baltimore, ArcGIS), Montgomery County (dataMontgomery), and Prince George's
  County. Adds a key-less ArcGIS provider type alongside the existing police.uk
  and Socrata feeds, and casts Socrata lat/lng to numbers so portals that store
  coordinates as text (e.g. Montgomery) query correctly.
- Map-first tab shell: Map, Routes, Safety, Contacts, Profile.
- Interactive safety map (MapKit) with a nearby-service category filter
  (police, hospital, fire, pharmacy, transport, taxi, 24-hour) and a crime-
  heatmap toggle.
- Safer route planning screen with safety-factor weighting (crime, lighting,
  population, service proximity, time of day).
- Safety hub: SOS, live location sharing, and a check-in timer with per-
  scenario default durations and a one-tap "I'm safe" stand-down.
- Trusted-contacts roster with per-contact alert opt-in, stored locally.
- Emergency medical profile (blood type, allergies, conditions, medications,
  notes) kept on-device.
- App icon: glossy white disc with a checkmark-shield on a calm teal field.
- Live nearby-service search: real MapKit points-of-interest pins for the
  toggled-on categories, updated as you pan the map.
- SOS and live-share alerts now send a pre-filled SMS to your alert contacts
  with a tappable Apple Maps link to your location — no account, no server.
- Safety check-in timer is real: it survives an app relaunch and schedules a
  local notification that fires if the deadline passes without "I'm safe".
- Crime heatmap overlay with a pluggable, key-less open-data backend. Queried
  over the visible map polygon so it fills the viewport; areas with no wired
  source show a "no crime data" note. Supported regions:
  - United Kingdom — police.uk
  - Chicago — City of Chicago open data
  - New York — NYPD complaint data
  - San Francisco — SFPD incident reports
  - Los Angeles — LAPD crime data
- Safer routing: **long-press anywhere on the map** to draw a walking route
  there, or type a destination in the Routes tab. When crime data is loaded and
  "prefer safer routes" is on, the route passing the fewest reported crimes is
  chosen over the fastest; alternates are drawn faint, the pick bold, with a
  route card showing time/distance and why it won.
- Typing a destination in the **Routes tab now keeps the results there** instead
  of jumping to the map: it loads nearby crime, scores every route, and lists
  them in-page (each selectable, with its safety badge) so you can compare before
  opening the map. Routes picked on the map appear here too (shared
  `RoutePlanner`). (`RoutePlanner.crimePoints`)
- **Danger routes show red.** When a safer route is chosen over an alternate that
  passes through a clearly-risky area, that avoided path is now drawn red on the
  map — the danger you steered around is visible, not just implied.
  (`RoutePlanner.dangerRoutes`)
- First-run intro that explains the app and primes location + notification
  permissions before you reach the map.
- Missed-check-in alerts: when a safety timer runs out, Aware prompts you to
  alert your contacts (or confirm you're safe) — on the lock-screen notification
  and the next time you open the app.
- Import trusted contacts straight from your address book.
- Live Activity: an active SOS, live-share or check-in session shows on the
  lock screen and in the Dynamic Island, with a live countdown for timers.
- The crime heatmap is now a real, smooth heat field — a blurred density raster
  (amber → red) instead of a grid of overlapping discs. It reads like a proper
  heatmap and renders as a single lightweight overlay, so panning stays smooth.
- **Safety ratings.** A coarse safety band (All clear / Low / Moderate / High /
  Very high) from nearby reported-crime density, shown in two places. A "Your
  area" pill on the map rates the ring around where you are right now, and every
  walking route on the route card carries its own rating (crimes passed per km,
  so a long route isn't unfairly dinged). Multiple routes each show a badge, and
  you can tap one to pick it. (`SafetyRating`, `RoutePlanner.rating`)
- Double-tap anywhere on the heatmap for an **area insight**: how many crimes
  were reported nearby, a category breakdown, a Low → Very-high risk band, the
  data source, and a one-tap "route here safely" shortcut. (Double-tap so it
  doesn't clash with long-press routing.)

### Changed

- Removed the **Routes tab** — safer-route planning is fully handled on the Map
  now (long-press or destination search, with the in-place route list and red
  danger paths). The new Settings tab took its place in the tab bar.
- The safety map now renders on MapKit's MKMapView directly (the SwiftUI map
  can't host a custom raster overlay). Pins, routes, the user dot, long-press
  routing and the smoothness gates carried over unchanged.

### Fixed

- Map is smoother when panning and zooming. The heatmap no longer re-renders
  and jumps on every tiny camera settle (gated to meaningful moves), and
  nearby-service pins update in place rather than blinking out and streaming
  back in.
- The heatmap renders at higher resolution with a gaussian smoothing pass, so it
  looks like a soft field instead of blocky pixels.
- The map fills the whole screen again, so the filter chips and nav bar float
  over it as translucent glass (they were sitting on an opaque black band).

### Notes

- Still stubbed for a later pass: richer route weighting (lighting, population,
  time-of-day — currently crime-proximity + walking time) and importing trusted
  contacts from the address book.

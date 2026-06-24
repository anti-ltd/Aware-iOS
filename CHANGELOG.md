# Changelog

All notable changes to Aware are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this file is baked
into the app at build time (`make changelog`) and shown under
Settings → Changelog.

## [1.0] (B4) - 2026-06-24

Settings info docs, coverage map, and What's New, aligned with Spot.

### Added

- **What's New.** Returning users get a per-build highlight sheet (New, Updates,
  Fixes) baked from this changelog. Replay it from Settings → Replay.
- **Settings info docs.** Changelog, Sources, Coverage, Privacy, and Roadmap sit
  in Settings → About, same pattern as Spot.
- **Settings tab.** App preferences moved off Profile. Routes & map toggles, safety
  options, and the info-doc pages live here now. Profile keeps the emergency
  medical card.
- **Data sources page.** Honest breakdown of crime feeds, Apple Maps, and what
  stays on your phone.
- **Coverage map.** Full-screen map with crime-footprint polygons and a region
  list, synced from anti.ltd.
- **Maryland crime data.** Baltimore City, Montgomery County, and Prince
  George's County join the heatmap alongside the existing UK and US city feeds.
- **Map-first tabs.** Map, Safety, Contacts, Profile, Settings.
- **Safety map.** Nearby police, hospitals, fire, pharmacies, transport, taxis,
  and 24-hour spots from MapKit, plus an optional crime heatmap.
- **Safer routes.** Long-press the map or search a destination. With crime data
  loaded and "prefer safer routes" on, Aware picks the route past the fewest
  reported crimes, not just the fastest.
- **SOS and live sharing.** One tap sends a pre-filled SMS to trusted contacts
  with a tappable Apple Maps link. No account, no server.
- **Check-in timer.** Survives a relaunch and fires a local notification if you
  miss the deadline before tapping "I'm safe".
- **Trusted contacts.** Local roster with per-contact alert opt-in and address-book
  import.
- **Emergency profile.** Blood type, allergies, conditions, medications, and
  notes, stored on-device only.
- **Live Activity.** Active SOS, live-share, or timer sessions show on the lock
  screen and Dynamic Island.
- **Crime heatmap.** Smooth density field (amber to red) from open police data.
  Queried for whatever map area you're viewing. Working regions today:
  - United Kingdom (police.uk)
  - Chicago, New York, San Francisco, Los Angeles
  - Baltimore, Montgomery County, Prince George's County
- **Safety ratings.** Coarse band (All clear through Very high) on the map pill
  and on each walking route, scored by crimes per km so long routes aren't
  unfairly penalised.
- **Area insight.** Double-tap the heatmap for nearby crime count, categories,
  risk band, data source, and a shortcut to route there safely.
- **Danger routes in red.** When a safer pick avoids a risky alternate, that
  avoided path draws red on the map.
- **First-run intro.** Walkthrough plus location and notification priming before
  you reach the map.

### Changed

- **Routes tab removed.** Safer routing is on the map now (long-press or search,
  in-place route list, red danger paths). Settings took the tab slot.
- **MKMapView renderer.** The heatmap needs a custom raster overlay, so the map
  runs on MKMapView instead of SwiftUI Map. Pins, routes, and gestures carried
  over.

### Fixed

- **Map pan and zoom.** Heatmap no longer re-renders on every tiny camera settle.
  Nearby-service pins update in place instead of blinking out.
- **Heatmap quality.** Higher resolution plus a gaussian pass so the field reads
  smooth, not blocky.
- **Full-screen map.** Filter chips and the nav bar float over the map again
  instead of sitting on an opaque black band.

### Notes

- Still on the list: richer route weighting (lighting, population, time of day)
  on top of crime proximity and walking time.

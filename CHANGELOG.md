# Changelog

All notable changes to Aware are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this file is baked
into the app at build time (`make changelog`) and shown under
Profile → About → Changelog.

## [0.1.0] - Unreleased

First scaffold of the map-first personal-safety app.

### Added

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
- First-run intro that explains the app and primes location + notification
  permissions before you reach the map.
- Missed-check-in alerts: when a safety timer runs out, Aware prompts you to
  alert your contacts (or confirm you're safe) — on the lock-screen notification
  and the next time you open the app.
- Import trusted contacts straight from your address book.
- Live Activity: an active SOS, live-share or check-in session shows on the
  lock screen and in the Dynamic Island, with a live countdown for timers.

### Notes

- Still stubbed for a later pass: richer route weighting (lighting, population,
  time-of-day — currently crime-proximity + walking time) and importing trusted
  contacts from the address book.

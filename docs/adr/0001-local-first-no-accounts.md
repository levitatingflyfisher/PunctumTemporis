# ADR-0001: Local-first, no accounts, no telemetry

- **Status:** Accepted
- **Date:** documenting a decision load-bearing since the first release

## Context

A one-second-a-day video diary accumulates the most sensitive record a family
keeps: faces of children, home interiors, daily locations, years of routine. The
popular incumbent stores this behind a cloud account and a subscription. That
model turns a private diary into someone else's data asset, adds an account and a
paywall, and makes the footage hostage to a service staying alive and honest.

We want the opposite defaults, and we want them to be *architectural* — provable
by the absence of code, not by a privacy-policy promise.

## Decision

Everything runs and stays on the device.

- **No account, no sign-up, no server contact** for any core function. The app is
  fully usable the instant it launches.
- **No network client for user data.** There is no code path that uploads clips,
  thumbnails, faces, or metadata. Capabilities that a lazier app would reach for a
  server to do are done locally instead:
  - reverse-geocoding uses a **bundled offline dataset** (`OfflineGeocoder` over
    `assets/data/cities.csv`), never a geocoding API;
  - fonts are **bundled** in `assets/fonts/` and referenced by family, never
    fetched from Google at runtime (locked by `test/theme/offline_fonts_test.dart`);
  - face detection and recognition run on device (ML Kit + a local TFLite model).
- **No ads, no analytics SDK, no tracking.**
- The **only** egress is a *user-initiated* action: the system share sheet, or
  exporting a backup ZIP the user chooses to save or send.
- **If sync is ever added**, it must travel as **encrypted blobs through a dumb
  relay** that cannot read them — never plaintext, never a BaaS
  (Firebase/Supabase/Auth0). As of today, no sync exists at all.

## Consequences

- **Buys:** a genuine privacy guarantee (the data path simply has no exit), zero
  running cost, full offline operation, no lock-in — the footage is a folder of
  MP4s the user owns.
- **Costs:** no cross-device access, no cloud backup safety net, no "log in on a
  new phone." Moving data means hand-carrying a backup ZIP. Some conveniences
  (server-side geocoding, model hosting) are done the harder, local way.
- **Forecloses:** any account system, any always-on network dependency, any
  third-party SDK that phones home. These are not features awaiting a sprint; they
  are outside the design.

## Alternatives considered

- **Cloud account + sync (the incumbent's model):** rejected — it is the exact
  thing this app exists to avoid.
- **"Optional" cloud backup to a BaaS:** rejected — even opt-in plaintext cloud
  storage of family footage violates the privacy invariant. The acceptable form
  is encrypted-blob-through-a-relay, and that is deferred, not compromised.

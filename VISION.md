# Vision

> The north star for Punctum Temporis. If you (person or agent) are about to
> change something load-bearing, read this first — it says what must stay true
> and why. For *how it's built*, see
> [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md); for *why each
> decision was made*, [docs/adr/](docs/adr/).

## The one idea

**One second a day — and it never leaves your hands.**

Record a single second of video every day. At the end of a stretch of days,
stitch those seconds into a film. That is the whole product, and millions of
people already love the idea. The difference here is the second half of the
sentence: the most intimate record you will ever keep — your family's faces,
where you were, what an ordinary Tuesday looked like — is captured, stored,
face-matched, and compiled **entirely on your device**. No account. No upload.
No subscription. No one else's server holding your life as an asset.

The paid incumbent ("1 Second Everyday") is a lovely app built on a cloud
account model. Punctum Temporis is the answer to a simple question: *does a
video diary need any of that?* It does not. The footage is yours; the code is
open; the network is optional and, today, unused for your data.

## What this is

A **local-first video journal** built with Flutter, shipping as an Android app
and an installable web PWA (works on iOS Safari without an App Store). It:

- captures a daily clip (record video, take a photo, or import from the gallery),
- generates thumbnails and, on device, detects and recognizes faces to auto-tag
  the people in each day,
- reverse-geocodes GPS to a city label using a **bundled offline dataset** (no
  geocoding API call),
- compiles any date range into a montage — vertical, normalized, with an
  optional date/location overlay and multi-track background music — via FFmpeg,
- backs up and restores everything as a single ZIP you control.

## Design commitments (the invariants)

These are the load-bearing beliefs Punctum Temporis shares with every OpenHearth
app, stated in this app's terms. Breaking one is a design regression, not a
feature. Each is recorded as an [ADR](docs/adr/).

1. **Local-first, not local-only.** On-device storage and full offline operation
   are the default and, today, the *entirety* of the data path. If sync is ever
   added it travels as **encrypted blobs through a dumb relay** — never plaintext,
   never a BaaS (no Firebase/Supabase/Auth0). ([ADR-0001](docs/adr/0001-local-first-no-accounts.md))
2. **No account required, ever.** There is no sign-up, no identity, no server
   contact for core use. The app is fully usable the second it launches.
3. **No ads, no tracking, no data sales — architecturally.** The runtime has no
   network client that sends your clips, metadata, or faces anywhere. The
   guarantee is the *absence of the code path*, not a promise.
4. **Privacy by default, and checkable.** Concretely: face reference images are
   cropped to the detected box on device, not stored as whole frames
   ([ADR-0004](docs/adr/0004-on-device-face-crop.md)); reverse-geocoding is
   offline ([ADR-0001](docs/adr/0001-local-first-no-accounts.md)); fonts are
   bundled, not fetched from Google at runtime; a restored backup is treated as
   untrusted input ([ADR-0005](docs/adr/0005-untrusted-backup-hardening.md)). See
   [docs/privacy-model.md](docs/privacy-model.md) for the "what leaves the device"
   ledger and how to verify it.
5. **FLOSS / open by default.** MIT-licensed. The code is a recipe worth sharing.
6. **Genuine craft.** A layered structure (models / services / platform / UI), a
   platform-twin so one codebase runs native and web
   ([ADR-0002](docs/adr/0002-platform-twin.md)), and a real test suite
   (30 test files, including golden layout regressions).

Right-sizing note: this is a *personal media* app, so the privacy story is
central and the sync story is deliberately empty for now. We say the true thing
rather than the impressive thing.

## Honest scorecard — built vs. aspirational

A guiding light has to tell the truth about where the light reaches. This code
and its comments were written by an AI assistant; treat them as **an accurate
record of what currently exists, offered with gratitude and a grain of salt** —
not as a specification, and not guaranteed-correct. Verify a claim (read the
code, run the test) before you rely on it.

**Real, tested, load-bearing:**
- Daily capture via camera, photo, or gallery import; multi-clip days with
  drag-to-reorder; post-capture trim.
- Calendar browsing with tag / location / people filters (AND logic).
- On-device face detection (ML Kit) + recognition (MobileFaceNet embeddings,
  cosine match) that auto-tags people, with reference thumbnails **cropped to the
  face box** for privacy.
- Offline reverse-geocoding to "City, CC" from a bundled cities dataset.
- FFmpeg compilation: per-clip vertical normalization, concat, date/location
  overlay, single- and multi-track audio mixing.
- ZIP backup / restore with merge-or-replace, hardened against zip bombs, ZIP
  Slip, and metadata path-traversal.
- Year-in-Review (heatmap, monthly bars, top locations/tags/faces), streak
  milestones, daily reminders, Android home-screen widget.
- A web PWA twin: OPFS storage + ffmpeg.wasm, so the same app installs from a URL.

**Aspirational — documented, not shipped:**
- **Any sync at all.** Today the app is strictly single-device. There is no
  encrypted-blob relay, no cross-device merge beyond hand-carrying a backup ZIP.
  The invariant above describes how sync *would* be built, not something built.
- **A bundled face model.** Face recognition needs a MobileFaceNet `.tflite` the
  user supplies; without it, detection/recognition is simply off. Nothing ships
  in the repo (size + licensing).
- **A native iOS app.** iOS is served as a PWA only.
- **Rich montage.** Compilation is straight normalized concat plus overlay — no
  real transitions, no smart editing.

The core loop — capture → recognize → compile → keep, all on device — is real.
Anything with the word *sync*, *cloud*, or *account* attached is deliberately
absent. Keep that line bright.

## Horizons (problems, not a dated feature list)

Framed as problems on purpose — for a project like this, describing a capability
precisely enough to schedule it is most of the work of building it.

- **Near** — Ship the face model story without a licensing or size landmine
  (guided download? an opt-in first-run fetch that the user initiates?). Richer
  montage transitions inside the existing FFmpeg pipeline.
- **Mid** — **Encrypted-blob sync through a relay that cannot read it.** The hard
  part is not the transport; it is a merge model for append-mostly per-day clip
  lists across devices with no server-side conflict resolver. This is the one
  feature that would change the product's shape, and it must not compromise
  invariants 1–4 to arrive.
- **Far** — At-rest encryption beyond the OS sandbox, so a lost unlocked device
  or a shared backup ZIP is not a plaintext leak of a decade of family footage.

## The name

**Punctum Temporis** — Latin for *a point of time*, an instant. A whole day
distilled to one second is exactly that: a punctum temporis. The phrase also
nods to the *punctum* of photography — the small, piercing detail in an image
that stays with you — which is what a one-second diary is built to catch.

*(A factual note for maintainers: the internal Dart package is still named
`one_second_a_day`, and some class names — `OneSecondApp`, storage paths under
`OneSecondADay` — reflect that history. The product is **Punctum Temporis**; the
package name is legacy, not a second identity.)*

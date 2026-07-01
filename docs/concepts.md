# Concepts

The domain model in prose — the handful of ideas the whole app is built from.
For field-level detail see [reference/data-model.md](reference/data-model.md); for
the mechanics see [reference/pipeline.md](reference/pipeline.md).

## The second, the day, the film

The unit is the **second**. Each day you record roughly one second of video — a
`Clip`. A **day** (`YYYY-MM-DD`) is the organizing key; it can hold more than one
clip (you can capture twice, or import a stray photo onto the right date), and the
day's clips have an order you can drag to change. A **film** — a `Compilation` —
is what you get when you stitch a range of days' clips end to end. That is the
entire loop: seconds accrete into days, days compile into a film.

A clip doesn't have to be recorded live. It can be a **photo** turned into a
one-second clip, or an **imported** video/photo from the gallery placed on a past
date. The gallery importer even surfaces `±1 day` "nearby" media, because the
day a photo was *taken* and the day its file claims often disagree (`exifDate`
vs. `date`, surfaced as `hasDateMismatch`).

## People are faces you've named

There is no contacts list. A **person** is simply a name you attached to a face.
When face recognition is on (native, with a model present), each new clip's
thumbnail is scanned; recognized faces add that person's name to the clip's
`detectedFaces`, and the name is also mirrored into the clip's tags so filters
treat "people" and "tags" uniformly. The app remembers a person as a small set of
**reference embeddings** (`knownPeople`) plus one cropped face image — nothing
more. See [privacy-model.md](privacy-model.md) for why the stored image is
cropped.

Recognition is a *convenience*, never a requirement: with no model, the whole
face system is simply off and everything else works.

## Place is a city, computed offline

If you allow location, a clip carries GPS coordinates and a human **`locationLabel`**
like `"Paris, FR"`. That label is computed **on the device** from a bundled cities
dataset (nearest city by great-circle distance), not by asking a server. Location
is therefore private and works on a plane. It is also deliberately coarse — a city,
not a street.

## Filters and streaks are views over the map

Everything the app "knows" is the in-memory map of day → clips. The richer screens
are just views over it:

- **Calendar filters** — tag, location, and people chips combine with **AND**
  logic; non-matching days dim rather than disappear, so the shape of your history
  stays visible.
- **Year-in-Review** — a heatmap of which days you captured, monthly bars, and top
  locations/tags/faces, all aggregated in Dart over the same map.
- **Streaks & milestones** — a streak is the run of consecutive captured days;
  crossing 7 / 30 / 50 / 100 / 200 / 365 fires a one-time celebration (tracked so
  it doesn't re-fire).

None of these are separate data stores; they are computations. That is why the
persistence layer can be a single JSON file
([ADR-0003](adr/0003-json-metadata-no-db.md)).

## One app, two runtimes

The same app is a native Android build and an installable **web PWA**. A
"platform twin" ([ADR-0002](adr/0002-platform-twin.md)) swaps the native pieces
(filesystem, FFmpeg binary, ML Kit, notifications) for web equivalents (OPFS,
ffmpeg.wasm) or honest stubs (no face recognition, no push, no widget on web). The
*concepts* above are identical on both; only the capabilities differ.

## Look and feel is a switch, not a rewrite

Presentation is themeable through three **visual styles** — **Retro** (a CRT
aesthetic with pixel fonts and a scanline overlay), **Modern** (clean Material 3),
and **Hearth** (a warm OpenHearth palette, the default). The style is a single
setting read by `AppTheme`; fonts for every style are **bundled** (a local-first
requirement — no runtime font fetch).

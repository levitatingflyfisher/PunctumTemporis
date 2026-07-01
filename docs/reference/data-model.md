# Reference: data model & feature status

Grounded in `lib/models/clip.dart` and the `metadata.json` (de)serialization in
`lib/services/storage_service.dart`.

## `Clip`

One captured second (or a still turned into one). Days can hold multiple clips.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID; used for dedup on merge/reorder |
| `date` | `String` | `YYYY-MM-DD` — the day this clip belongs to (the map key) |
| `filePath` | `String` | path to the clip MP4 (app-private `clips/`) |
| `thumbnailPath` | `String?` | JPEG thumbnail (`thumbnails/`) |
| `type` | `ClipType` | `video` · `photo` · `imported` |
| `createdAt` | `DateTime` | when the clip record was created |
| `capturedAt` | `DateTime?` | original capture time if known |
| `notes` | `String?` | free text |
| `duration` | `double?` | seconds |
| `exifDate` | `String?` | original media date; `hasDateMismatch` = `exifDate != date` |
| `tags` | `List<String>` | user tags (people names are also mirrored in as tags) |
| `latitude` / `longitude` | `double?` | GPS |
| `locationLabel` | `String?` | offline-geocoded `"City, CC"` |
| `detectedFaces` | `List<String>` | recognized person names (native only) |

`copyWith` uses a `_sentinel` const to distinguish "not provided" from "set to
null" — needed because most fields are nullable. `toJson`/`fromJson` are
hand-written; `fromJson` tolerates missing lists (defaults to `[]`) and an unknown
`type` (defaults to `video`).

## `Compilation`

A rendered montage over a set of clips.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID |
| `title` | `String` | display title |
| `filePath` | `String` | rendered MP4 (public `Movies/OneSecondADay/compilations/`; restored rows are re-pinned to the app-private `compiled/`) |
| `clipIds` | `List<String>` | clips included, in order |
| `createdAt` | `DateTime` | render time |
| `startDate` / `endDate` | `String?` | covered range |
| `duration` | `double?` | seconds |
| `originalVolume` | `double?` | recipe: clip-audio level at compile time (`null` on pre-1.5 rows) |
| `audioSegments` | `List<AudioSegment>?` | recipe: music tracks with timing/volume (`null` on pre-1.5 rows) |

## `AudioSegment`

A background-audio track placed on the compilation timeline (see the multi-track
graph in [pipeline.md](pipeline.md)).

| Field | Type | Notes |
|---|---|---|
| `filePath` / `fileName` | `String` | the audio file |
| `startTimeInCompilation` | `double` | seconds from the montage start (→ `adelay`) |
| `audioOffset` | `double` | seconds into the audio file to begin (→ `atrim start`) |
| `duration` | `double?` | play length; `null` = to end of audio/compilation |
| `volume` | `double` | `0.0`–`1.0` (default `0.3`) |

## `metadata.json` on-disk shape

One file in the app-private dir; the whole thing is rewritten on every mutation
([ADR-0003](../adr/0003-json-metadata-no-db.md)).

```jsonc
{
  "clips": {
    "2026-03-20": [ { /* Clip.toJson */ }, { /* ... */ } ],
    "2026-03-21": [ { /* ... */ } ]
  },
  "compilations": [ { /* Compilation.toJson */ } ],
  "knownPeople": {
    "Alex": [ [/* 192 doubles */], [/* another reference embedding */] ]
  }
}
```

Loader tolerances (`_loadMetadata`): a `clips` value may legacy-decode from a
single object *or* a list; `knownPeople` embeddings are coerced to `double`;
malformed JSON resets to empty rather than throwing. On restore, all of this is
re-pinned to safe paths first — see
[ADR-0005](../adr/0005-untrusted-backup-hardening.md).

Sibling media directories (not in the JSON): `clips/`, `thumbnails/`,
`faces/<name>.jpg`. Settings live in `shared_preferences`, not here (theme mode,
accent color, visual style, CRT toggle, date format, capture-location toggle,
location-overlay toggle, reminder enabled/time, pinned tags/locations, onboarding
complete, celebrated milestones, clips-migrated flag).

## Feature status

| Feature | Android | Web PWA |
|---|---|---|
| Daily capture — record / photo / import | ✅ | ✅ (import) |
| Multi-clip days + drag-reorder + trim | ✅ | ✅ |
| Calendar + tag/location/people filters (AND) | ✅ | ✅ |
| FFmpeg compile (concat + overlay + audio) | ✅ FFmpegKit | ✅ ffmpeg.wasm |
| Offline reverse-geocoding | ✅ | ✅ |
| Face detection + recognition | ✅ (needs model) | ❌ stub |
| On-device face crop for references | ✅ | n/a |
| ZIP backup / restore (hardened) | ✅ | ✅ (browser download) |
| Year-in-Review, streaks, milestones | ✅ | ✅ |
| Daily reminder notifications | ✅ | ❌ stub |
| Home-screen widget | ✅ | ❌ |
| Retro / Modern / Hearth visual styles | ✅ | ✅ |
| Cloud sync / accounts | ❌ (by design) | ❌ (by design) |

"By design" = an invariant, not a gap awaiting a sprint — see
[VISION.md](../../VISION.md) and [limitations.md](../limitations.md).

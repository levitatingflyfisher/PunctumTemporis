# ADR-0004: Store face references cropped to the detected box, on device

- **Status:** Accepted
- **Date:** documenting the on-device-crop decision (privacy hardening)

## Context

To recognize people across days, the app keeps a small reference image per named
person and compares new faces against stored MobileFaceNet embeddings. The
question is *what image to keep*. The easy implementation copies the whole clip
thumbnail — but that thumbnail is a full frame: a living room, other people, a
child's bedroom in the background. Storing whole frames under a person's name
turns a face gallery into an incidental scrape of everything behind every face,
and those files travel inside every backup.

Separately, all of this must stay on device — sending faces to a recognition API
would violate [ADR-0001](0001-local-first-no-accounts.md).

## Decision

Face recognition runs entirely on device (ML Kit detection + a local
MobileFaceNet TFLite model), and a stored reference image is **cropped to the
detected bounding box** before it is written.

- `saveFaceImage(name, sourceImagePath, boundingBox)` calls `cropFaceJpg`
  (`lib/services/face_crop.dart`), which decodes the source, clamps the box to the
  image bounds, `copyCrop`s to just the face, and re-encodes JPEG to
  `faces/<name>.jpg`.
- The box is **clamped** (ML Kit boxes routinely extend past image edges), so a
  crop never throws on an out-of-bounds rectangle.
- **Fail safe:** if the source bytes can't be read or decoded, `cropFaceJpg`
  returns `null` and the caller falls back to copying the whole image — a slightly
  less private reference is preferred to *losing the face* and breaking
  recognition. This fallback is the deliberate exception, not the norm.

## Consequences

- **Buys:** the face gallery contains faces, not rooms. Backups carry only cropped
  faces. Combined with on-device inference, no recognition data ever leaves the
  device.
- **Costs:** an extra decode + crop + encode per saved reference. A tight ML Kit
  box can clip forehead/chin, and the rare undecodable-source fallback still stores
  a whole frame (logged, and bounded to that one case).
- **Forecloses:** storing whole frames as face references "for context." If a
  future feature needs surrounding context, it must not reintroduce whole-frame
  storage under a person's identity.

## Alternatives considered

- **Copy the whole thumbnail as the reference:** rejected — the privacy leak
  described above.
- **Store no reference image, only the embedding:** viable for matching, but the
  UI shows a face chip per person; a cropped thumbnail is the least-data way to
  support that. Chosen as the balance of privacy and usability.
- **Cloud face API:** rejected outright — violates [ADR-0001](0001-local-first-no-accounts.md).

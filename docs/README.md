# Documentation

Organized on the [Diátaxis](https://diataxis.fr/) model — four kinds of docs for
four different needs. Find what you need by *what you're trying to do*, not by
guessing a filename.

| I want to… | I need | Go to |
|---|---|---|
| **learn by doing** | a Tutorial | [Tutorials](#tutorials) |
| **accomplish a specific task** | a How-to guide | [How-to guides](#how-to-guides) |
| **look up exact details** | Reference | [Reference](#reference) |
| **understand why** | Explanation | [Explanation](#explanation) |

New here? Start with the [README quickstart](../README.md), then
[Explanation § concepts](concepts.md), then the [architecture overview](architecture/OVERVIEW.md).

---

## Tutorials
*Learning-oriented — take me by the hand through my first success.*

- The **[README quickstart](../README.md#build--run)** — install Flutter deps,
  run the app, capture your first second.

*Gap (contributions welcome):* a hand-held "record 7 days and compile your first
montage in 10 minutes" walkthrough. If you write one, put it in `docs/tutorials/`.

## How-to guides
*Task-oriented — how do I accomplish X (assumes you know the basics)?*

- **[Build & run](how-to/build-and-run.md)** — dev loop, the face model, split
  APKs, tests and goldens.
- **[Ship the web PWA](how-to/ship-web-pwa.md)** — the web build, OPFS, the
  cross-origin-isolation requirement for ffmpeg.wasm, and the deploy workflows.
- **[Back up & restore](how-to/backup-and-restore.md)** — create, validate, and
  restore a backup ZIP; merge vs. replace; what the safety checks do.
- Agent-guidance for working *in* this repo: **[AGENTS.md](../AGENTS.md)**.

## Reference
*Information-oriented — tell me exactly, precisely, completely.*

- **[The pipeline](reference/pipeline.md)** — the capture → thumbnail → face →
  compile path, with the exact FFmpeg commands and the face-crop privacy steps.
- **[Data model & feature status](reference/data-model.md)** — `Clip`,
  `Compilation`, `AudioSegment`, the `metadata.json` shape, and the
  native-vs-web capability matrix.

## Explanation
*Understanding-oriented — help me understand the ideas and the why.*

- **[Vision](../VISION.md)** — the one idea, the invariants, the honest scorecard.
- **[Architecture overview](architecture/OVERVIEW.md)** — the layers, the platform
  twin, the data flow (with diagrams).
- **[Architecture Decision Records](adr/)** — why each load-bearing choice was made.
- **[Concepts](concepts.md)** — clips, days, compilations, faces-as-people,
  streaks; the domain model in prose.
- **[Privacy model](privacy-model.md)** — what does (and does not) leave the
  device, and how to check it yourself.
- **[Limitations](limitations.md)** — read before adopting. What it does *not* do.

---

### The white paper

- **[White paper](whitepaper.md)** — the conceptual case: why a video diary needs
  no cloud, who it's for, and how it differs from the subscription incumbent.

*(There is no "yellow paper" / formal spec: Punctum Temporis has no algorithmic
core that warrants machine-checkable formalism. The pieces that come closest — the
face-box clamp, the zip-bomb ceilings — are specified precisely in
[reference/pipeline.md](reference/pipeline.md) and
[ADR-0005](adr/0005-untrusted-backup-hardening.md) instead.)*

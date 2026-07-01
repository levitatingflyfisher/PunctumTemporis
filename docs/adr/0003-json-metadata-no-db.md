# ADR-0003: Persist to a single `metadata.json` file, not a database

- **Status:** Accepted
- **Date:** documenting a decision load-bearing since the first release

## Context

The app needs to persist a modest amount of structured data: a map of date →
list of clips, a list of compilations, and a `knownPeople` map of name →
embeddings. The *bulk* of the data is not structured at all — it is the MP4 clips
and JPEG thumbnails/faces on disk. The elsewhere-standard OpenHearth choice is
Drift over sqflite. Here the data set is small, single-user, and append-mostly,
and a headline requirement is that **backup is trivial** — the user should be able
to carry their whole diary as one ZIP.

## Decision

Persist all structured metadata as a single **`metadata.json`** file in the
app-private directory, managed by `StorageService`.

- The whole clip map is held **in memory**; every mutation calls `_saveMetadata()`
  which re-serializes and rewrites the file.
- `Clip`, `Compilation`, and `AudioSegment` own their own `toJson`/`fromJson`.
- Settings (theme, reminder time, pins, onboarding, celebrated milestones) live in
  `shared_preferences`, not in the JSON.
- No ORM, no schema, no migrations table. One-off data moves (e.g. relocating
  clips to app-private storage) are handled by imperative migration methods gated
  on a `shared_preferences` flag.

This also means **no reactive state framework**: screens receive the injected
`StorageService` and rebuild with `setState`. There is no Riverpod, no Drift, no
BLoC in this app.

## Consequences

- **Buys:** backup and restore are almost free — zip the media dirs plus
  `metadata.json` and you have everything (see
  [ADR-0005](0005-untrusted-backup-hardening.md)). No schema migrations to babysit.
  The whole persistence layer is a few hundred readable lines. Trivially inspectable
  and portable.
- **Costs:** every save rewrites the entire file (fine at a few years of daily
  clips; would not scale to hundreds of thousands of rows). No indexed queries —
  filtering/aggregation is done in Dart over the in-memory map. A corrupt write
  could lose the index (mitigated by the on-disk media being re-scannable and by
  backups).
- **Forecloses:** SQL-style querying and partial/streaming persistence. If the
  data model ever grows relational or large, this is the decision to revisit
  first.

## Alternatives considered

- **Drift/sqflite (the fleet default):** rejected here — buys indexed queries and
  migrations the app does not need, and makes "back up your whole diary as a file"
  harder, not easier. Deliberately *not* adopted; don't "modernize" into it
  without a real query/scale need.
- **One file per clip:** rejected — more open handles and directory churn for no
  gain over a single small index rewritten in memory.

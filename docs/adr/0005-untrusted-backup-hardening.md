# ADR-0005: Treat a restored backup ZIP as untrusted input

- **Status:** Accepted
- **Date:** documenting the backup-hardening decision

## Context

Backup/restore ([ADR-0003](0003-json-metadata-no-db.md)'s payoff) lets a user
carry their whole diary as a ZIP and share it. The moment restore accepts a file
the user *received* rather than created, that ZIP is **attacker-controlled input**.
A naive extractor exposes three classic archive attacks:

- **Zip bomb** — a tiny archive that decompresses to gigabytes, exhausting memory
  or storage.
- **ZIP Slip / path traversal** — an entry named `../../foo` that writes outside
  the intended directory.
- **Metadata path poisoning** — a crafted `metadata.json` whose clip `filePath`,
  `thumbnailPath`, or `knownPeople` key points at an arbitrary file, so a later
  "Create Backup" reads that file into the export, or a delete unlinks it.

## Decision

Restore validates before it trusts, in `BackupService`:

- **Zip-bomb ceilings, checked before decompression.** `checkArchiveLimits`
  rejects an archive that *declares* more than the ceilings — max entries
  (`50000`), max per-entry size (`2 GB`), max total (`8 GB`) — using each entry's
  header-declared size, so a bomb is refused without ever allocating its expanded
  payload. Runs on both `validateBackup` and `restoreBackup`.
- **ZIP-Slip rejection.** `_isSafeEntryName` drops any entry whose path contains
  `..`, `.`, or empty segments; such entries are skipped, not written.
- **Path pinning on restored metadata.** `sanitizeRestoredMetadata` rewrites every
  restored `filePath`/`thumbnailPath` to `"<ourDir>/<safeBasename>"` (last path
  segment only, traversal stripped) and **drops** any `knownPeople` key that isn't
  a safe plain basename (no separators, `..`, quotes, or newlines). A restored clip
  can therefore only ever point inside our own media directories.
- **Merge is ID-deduplicated.** Non-replace restore adds only clips/compilations
  whose IDs aren't already present, so a re-restore can't duplicate a diary.

## Consequences

- **Buys:** restoring a backup from anywhere is safe. A malicious ZIP cannot bomb
  memory, escape the media dirs, or aim the app's own file operations at the user's
  other files.
- **Costs:** a legitimate-but-enormous backup (beyond the ceilings) is refused and
  the user must split it. Path pinning means a restored path is *reconstructed*, so
  the backup format must keep the actual bytes under `clips/`, `thumbnails/`,
  `faces/` — the metadata path is advisory, not authoritative.
- **Forecloses:** trusting any string from a backup verbatim. New backup fields
  must be sanitized on the way in, by default.

## Alternatives considered

- **Trust our own format (no checks):** rejected — a shared backup is not "our"
  file; the format is trivially forgeable.
- **Decompress then measure:** rejected for the bomb case — measuring after
  decompression means you've already paid the memory cost the check exists to
  avoid. The declared-size pre-check is the point.

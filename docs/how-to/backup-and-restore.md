# How-to: back up & restore

Task-oriented. Your whole diary — clips, thumbnails, cropped faces, and the
`metadata.json` index — is portable as a single ZIP. This is how you move to a new
phone, keep an off-device copy, or share a diary. Implemented in
`lib/services/backup_service.dart`.

## Create a backup

In-app: **Settings → Backup / Restore → Create Backup**.

- **Native:** writes a `.zip` to the path you choose.
- **Web:** triggers a browser download named `onesecond_backup_<timestamp>.zip`.

What's inside:

```
metadata.json           # the index (clips, compilations, knownPeople)
settings.json           # allowlisted settings (theme, reminders, pins…)
clips/<file>.mp4        # source clips
thumbnails/<file>.jpg   # thumbnails
faces/<name>.jpg        # cropped face references (native only)
compilations/<file>.mp4 # montage videos (on by default, toggleable)
```

`getBackupSize()` estimates the total up front so the UI can show it.

### Montages travel too

Montages are the point of the app, so the finished MP4s ride along by
default — the **Include montage videos** switch next to the size estimate
opts a backup out when size matters. Each compilation row also carries its
*recipe* (clip-audio level and music segments with timing/volume), so
re-opening a montage seeds the compile controls exactly as you left them.

On restore, montage files are extracted into the app-private `compiled/`
dir and each row is re-pointed there. A row whose file didn't travel (old
backups, or a montage whose file was already gone at pack time) still
restores; opening it shows a quiet notice — the gallery usually still has
the original copy, and COMPILE rebuilds it from the clips.

> **The backup is a plaintext ZIP.** It is unencrypted by design (portable and
> inspectable). Guard it like the private footage it contains — see
> [privacy-model.md](../privacy-model.md).

## Validate before restoring

**Restore → pick a ZIP** first runs `validateBackup`, which shows the clip count,
date range, size, face count, and compilation count *before* you commit. Reading
the archive here also runs the safety ceilings (below), so a hostile file is
refused at validation time.

## Restore: merge vs. replace

Two modes:

- **Merge (default)** — adds clips, compilations, and people from the backup that
  aren't already present (deduplicated by `id`), keeping your current diary. Safe
  to run against a diary you're still using; re-running the same backup won't
  duplicate anything.
- **Replace** — overwrites existing files and metadata with the backup's.

After extraction the metadata is reloaded and the calendar refreshes.

## What the safety checks do (and why a restore might refuse)

A backup you *received* is untrusted input
([ADR-0005](../adr/0005-untrusted-backup-hardening.md)). Restore enforces:

- **Zip-bomb ceilings**, checked against the archive's *declared* sizes **before**
  decompression: ≤ 50 000 entries, ≤ 2 GB per file, ≤ 8 GB total. A `BackupTooLargeException`
  means the archive exceeded one of these — split a legitimately huge backup.
- **ZIP-Slip rejection** — entries whose paths contain `..`, `.`, or empty
  segments are skipped, so nothing is written outside the media dirs.
- **Metadata path pinning** — every restored clip/thumbnail/compilation path is
  rewritten to point inside your own `clips/`/`thumbnails/`/`compiled/` dirs
  (basename only), and unsafe `knownPeople` names are dropped. A crafted backup
  therefore can't aim the app's file operations (share, delete, the next
  backup's reads) at your other files.

If a restore silently skips some entries, it's these checks doing their job.

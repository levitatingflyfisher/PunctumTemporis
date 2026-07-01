# Migrate an install from the old app id

Punctum Temporis originally shipped under the Flutter-template id
`com.example.one_second_a_day`. Since v1.4.0 the APK is built as
`com.openhearth.punctumtemporis`. Android treats the two ids as **different
apps**, so an existing install never auto-updates to the new id — and that is
the safety feature this guide leans on: both versions can sit on the device at
the same time while you move your journal across. Nothing is deleted until you
choose to delete it.

## What moves, what doesn't

- **Moves via backup**: every clip video, thumbnails, face reference images,
  the journal index (`metadata.json`), and your settings. The backup zip is
  exactly this set, and restore verifies it.
- **Doesn't need to move**: rendered montages. They are written to the public
  `Movies/OneSecondADay/compilations/` folder, which belongs to the device,
  not the app — they survive uninstall untouched.

## Steps

1. **Update the old app one last time.** Install
   `PunctumTemporis-legacy.apk` from the `v0-apk` release. It has the old id,
   so it updates your existing install in place, and it contains the full
   Backup & Restore screen.
2. **Export a backup.** In the old app: Settings → Backup & Restore →
   Back Up Everything → *Save to Device* (pick Downloads). Wait for the
   "Backed up and verified — N clip files" receipt and note N.
3. **Install the new app.** Install `PunctumTemporis.apk` from the same
   release. It appears as a second Punctum Temporis icon — that's expected.
4. **Restore into the new app.** In the new app: Settings → Backup & Restore →
   Restore → pick the zip from Downloads → choose **Replace all**. The
   validation summary shows the clip count and date range before anything is
   written.
5. **Verify before deleting anything.** Open the calendar in the new app and
   spot-check: total clip count matches N, oldest and newest days play.
6. **Only then uninstall the old app** (the `com.example` icon). Keep the
   backup zip in Downloads as a belt-and-braces copy until you're confident.

If anything looks wrong at step 5, stop — the old app still has everything,
and the restore can be re-run or rolled back (a pre-restore snapshot is taken
automatically).

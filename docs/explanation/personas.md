# Personas

Agents drive the real Punctum Temporis build as these people, per the fleet
testing rule. Each scenario gives a start state, plain steps, what success
looks like, and what to check. "Standard checks" means: text scale 1.3 at
360 dp width, dark mode (and the default Hearth style), airplane mode, and
every error in plain words with a way forward. Scenarios aim at the weak
spots found by the September 2026 lens audit.

## Primary: Grace, a parent filming one second of each day of their baby's first year

Grace is 32, on parental leave with their first child, and wants a film of the
baby's first year to show the grandparents. They capture a second most
evenings, often at bath time, holding the baby in the other arm.

- **Goal:** capture today's second in as few taps as possible and see the day
  marked on the calendar.
- **Context:** one-handed, damp hands, dim evening light, interrupted often.
- **Would quit if:** a day's clip is lost or replaced by a spinner forever.

**G1. Capture today.** Start: fresh install, onboarding done, no clips. Steps:
tap CAPTURE; choose Record Video; record about one second; save. Success: the
calendar shows today as captured and still marks it as today; no modal stands
in the way. Check: standard checks; "Import from Gallery" reads in full at 1.3.

**G2. The streak dialog.** Start: clips on the previous six days. Steps:
capture today (the seventh). Success: feedback appears in the calendar itself,
or a dialog closes with a plain "Close"; no forced "AWESOME". Check: dark mode.

**G3. A missing clip file.** Start: a day with a clip whose file has been
removed from storage. Steps: open that day. Success: a plain sentence says the
clip file is missing and what to do; no endless spinner; no "Video file not
found" flash only. Check: no exception text such as "Camera error:".

**G4. Delete and regret.** Start: three days with clips. Steps: open one day,
delete its clip. Success: no dialog; the clip leaves the day at once and an
Undo stays at the bottom of the screen until acted on (it never times out),
even after the preview closes. Check: Undo brings the clip back to the
calendar; the bar names the day readably ("Sep 4, 2026", not "2026-09-04").

**G5. Backup honesty.** Start: clips with face tags and locations. Steps: open
Backup & Restore; create a backup; reach the share sheet. Success: a sentence
says the backup is an unprotected ZIP before it is shared. Check: CREATE
BACKUP is disabled with zero clips; the reminder setting is findable.

## Secondary: Elijah, the family's film-maker at year end

Elijah is 58, Grace's parent, visiting for the holidays. They use a phone with
large text and are not confident with icon-only controls.

- **Goal:** find the Year in Review and compile the year into one film.
- **Context:** text scale 1.3, sits at a table, reads labels carefully.
- **Would quit if:** they cannot tell which icon does what, or back does
  nothing during a long job.

**E1. Find the controls.** Start: a populated calendar. Steps: identify
Filter, Year, Compile and Settings from the home screen. Success: each has a
visible word or a tooltip; the app name is not cut to "ONE ...". Check:
standard checks.

**E2. Year in Review.** Start: clips across several months. Steps: open Year
in Review; read streak, rate and the heatmap. Success: each number appears
once; the whole year's heatmap is visible at phone width. Check: dark mode.

**E3. Compile and back out.** Start: 30 days of clips. Steps: start a
compilation; press back during processing. Success: back works, either
continuing in the background or offering to cancel; no "please wait" wall.
Check: offline.

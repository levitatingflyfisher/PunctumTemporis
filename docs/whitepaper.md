# Punctum Temporis — White Paper

*Why a video diary needs no cloud: a local-first, own-your-footage alternative to
the subscription memory app.*

**Status:** conceptual/strategic overview. For the invariants see
[VISION.md](../VISION.md); for the mechanics,
[architecture/OVERVIEW.md](architecture/OVERVIEW.md) and
[reference/pipeline.md](reference/pipeline.md). Honest about the line between built
and aspirational — see §6.

---

## Abstract

A one-second-a-day video diary is one of the most emotionally durable app ideas of
the last decade: a single second recorded each day, compiled into a film that
compresses a year into a few minutes. The popular product built on that idea
("1 Second Everyday") wraps it in a cloud account and a subscription. That wrapper
is not incidental — it turns the most private archive a family owns into a
third party's asset, gates it behind a recurring fee, and makes it hostage to a
service staying alive and trustworthy. Punctum Temporis asks whether any of that
is necessary, and answers no. It is a local-first Flutter app that captures,
face-recognizes, and compiles entirely on the device, ships as a free Android app
and an installable web PWA, and keeps your footage as ordinary files you own.

## 1. The problem with the cloud diary

The cloud model is convenient and it is also a poor fit for this specific data:

- **Sensitivity.** A daily video diary is a longitudinal record of children's
  faces, home interiors, and daily locations — precisely the data you'd least want
  on someone else's servers.
- **Ownership & continuity.** If your years of footage live behind an account, you
  don't fully own them: an outage, a price change, a shutdown, or a lost login
  puts them out of reach.
- **Cost & lock-in.** A subscription to store *your own* videos, in a proprietary
  format, is a recurring toll on your own memories.
- **Trust.** "We don't look at your data" is a policy, revocable and unverifiable.

None of these are failures of engineering; they are consequences of the
architecture. Change the architecture and they dissolve.

## 2. The idea

**Do the whole thing on the device, and make the footage plain files the user
owns.** Capture, thumbnailing, face detection and recognition, reverse-geocoding,
compilation, and backup all run locally. There is no account and no server that
handles user data. The privacy guarantee is not a promise in a policy; it is the
**absence of a network egress path**, which anyone can check (see
[privacy-model.md](privacy-model.md)).

This is the OpenHearth thesis applied to personal video: *local-first, no accounts,
no tracking, open source* — home-cooked software that serves the family rather
than monetizing it.

## 3. How it works (briefly)

One loop carries the product: capture → keep → compile.

- **Capture** a second — record, snap a photo (turned into a clip), or import from
  the gallery onto the right day.
- **Understand** it locally — a thumbnail, on-device face recognition (ML Kit +
  MobileFaceNet) that tags the people, and an **offline** GPS-to-city label.
- **Keep** it — as an MP4 plus a small `metadata.json` index, no database, no
  server.
- **Compile** a range — FFmpeg normalizes every clip to a common vertical format
  and stitches them, with an optional date/location overlay and multi-track music.

The same Dart codebase runs native (FFmpegKit, `dart:io`, ML Kit) and on the web
(ffmpeg.wasm, OPFS, stubs) via a compile-time **platform twin**, so an iPhone user
installs it from a URL with no App Store. Details:
[architecture/OVERVIEW.md](architecture/OVERVIEW.md).

## 4. Why local-first *here* specifically

Local-first is a general OpenHearth value, but this app is a near-ideal case for
it:

- **The data is inherently single-owner and single-timeline** — one person's diary,
  appended one day at a time. It doesn't need multi-user servers or real-time
  collaboration.
- **The heavy lifting is local anyway.** Video encoding and on-device ML don't
  benefit from a round trip to a server; doing them locally is both more private
  *and* often faster and free.
- **Backup is trivially a file.** Because the store is a folder of MP4s plus a JSON
  index, "own your data" isn't a slogan — it's a ZIP you can copy anywhere
  ([how-to/backup-and-restore.md](how-to/backup-and-restore.md)).

The privacy cost of the cloud model buys, for this app, almost nothing the user
actually needs.

## 5. Who it's for

Families and individuals who want the one-second-a-day ritual without renting
their memories back from a cloud: parents documenting a child's year, anyone
uneasy about faces of their kids on third-party servers, people who want their
footage to outlive any company, and privacy-minded users who value being able to
*verify* — not just be told — that nothing leaves their phone. It is free and open
source; there is nothing to buy and no account to create.

## 6. What is built, and what is not

A white paper that overclaims is marketing. Honestly:

**Built, tested, load-bearing:** the full capture → recognize → compile → keep
loop; camera/photo/import capture with multi-clip days, reorder, and trim; calendar
with tag/location/people filters; on-device face detection + recognition with
**cropped-to-the-box** reference storage; offline reverse-geocoding; FFmpeg
compilation (normalize, concat, overlay, single- and multi-track audio); hardened
ZIP backup/restore; Year-in-Review, streaks, reminders, and an Android widget; and
a working web PWA twin. A real test suite (30 files, including golden layout
regressions) backs it.

**Aspirational — documented, not code:** there is **no sync of any kind** — the app
is single-device today; the encrypted-blob-relay design in
[ADR-0001](adr/0001-local-first-no-accounts.md) is a plan, not a build. There is
**no bundled face model** (the user supplies one). There is **no native iOS app**
(PWA only). Compilation is straight normalized concat — **no real transitions**.
And there is **no at-rest encryption** beyond the OS sandbox, so a plaintext backup
or a lost unlocked phone is out of scope for now
([limitations.md](limitations.md)).

## 7. Why it's worth doing

Because the alternative — renting your own family footage back from a cloud you
must trust — is the default, and it is the wrong default for the single most
private archive most households will ever keep. The contribution isn't a new
algorithm; it's the demonstration that a beloved product idea works *better*
without the account, the server, and the subscription: more private, more durable,
more genuinely the user's own. Local-first isn't a constraint here. It's the
feature.

---

*The code and comments referenced here were authored by an AI assistant and
describe what currently exists — take them with gratitude and a grain of salt, and
verify before relying.*

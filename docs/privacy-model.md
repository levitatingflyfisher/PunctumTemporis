# Privacy model

Punctum Temporis holds an unusually sensitive dataset — years of a family's
faces, homes, and daily locations. This page states exactly what does and does not
leave the device, and how you can check it yourself. See
[ADR-0001](adr/0001-local-first-no-accounts.md) and
[ADR-0004](adr/0004-on-device-face-crop.md) for the decisions behind it.

## Threat model (who this protects against)

- **The app maker / a cloud service** — there is no service; there is nothing to
  hand over, subpoena, breach, or monetize. Not applicable by construction.
- **Passive network observers / trackers** — the runtime makes no requests
  carrying user data, so there is no traffic to observe.
- **Other apps on the device** — clips, thumbnails, faces, and metadata live in
  the app-private directory (OS-sandboxed); only *compiled* montages are written
  to the public `Movies/` folder, and only because a finished film is meant to be
  shared.
- **A malicious backup you were given** — restore treats the ZIP as untrusted
  input (zip-bomb, ZIP-Slip, path-poisoning defenses — see
  [ADR-0005](adr/0005-untrusted-backup-hardening.md)).

Explicitly **out of scope** (see [limitations.md](limitations.md)): a thief with
your *unlocked* phone, forensic recovery of the raw files, and anyone you
*choose* to share a clip or backup with. There is no at-rest encryption beyond the
OS sandbox yet.

## What leaves the device

| Data | Leaves at runtime? | Notes |
|---|---|---|
| Clips, thumbnails, face images | **No** | app-private storage / OPFS |
| Clip metadata (dates, tags, GPS, people) | **No** | `metadata.json`, on device |
| Face embeddings & recognition | **No** | ML Kit + MobileFaceNet run on device |
| GPS → city label | **No** | offline geocoder over a bundled dataset |
| Fonts | **No** | bundled in `assets/fonts/`, not fetched from Google |
| Crash/usage analytics | **No** | there is no analytics SDK |
| A clip or montage you tap "share" on | **Yes — you initiated it** | goes wherever you send it, via the OS share sheet |
| A backup ZIP you export | **Yes — you initiated it** | plaintext archive; treat like any file with private contents |

The only egress is a **deliberate user action**. Nothing is automatic, scheduled,
or background.

## Privacy-preserving details worth knowing

- **Faces are stored cropped.** A person's reference image is cropped to the
  detected face box, not the surrounding room — so backups and the face gallery
  don't incidentally hoard everything behind every face
  ([ADR-0004](adr/0004-on-device-face-crop.md)).
- **Location is coarse and local.** The label is a nearest *city*, computed on
  device — never a street address, never a lookup service.
- **Face recognition is opt-in by omission.** With no model file present, the
  entire face system is inert.
- **A backup is plaintext.** The convenience of "your whole diary is one portable
  ZIP" means that ZIP is unencrypted. Guard it like the footage it contains.

## Verify it yourself

You don't have to trust this page:

1. **Read the deps.** `pubspec.yaml` has no analytics/crash/BaaS packages
   (no Firebase, Sentry, Amplitude, etc.). Network-capable packages present are
   there for GPS, media, and sharing — not for exfiltration.
2. **Grep for a network client.** Search `lib/` for `http`, `dio`, `HttpClient`,
   `Socket`, `fetch` — you'll find no code uploading clips, thumbnails, faces, or
   metadata.
3. **Watch the traffic.** Put the phone behind a proxy (or use airplane mode) and
   exercise capture → recognize → compile. Everything works offline; no user data
   is sent.
4. **The font test proves one case.** `test/theme/offline_fonts_test.dart` locks
   every visual style to bundled font families, so a regression to runtime font
   egress fails the build.

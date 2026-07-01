// PT's vault snapshots move onto the fleet-standard BackupEnvelope
// (C2-backup): new snapshots are wrapped `{app, schemaVersion, createdAt,
// payload: {metadata, settings}}`, while BOTH legacy on-disk shapes — the
// v2 composite `{snapshotVersion, metadata, settings}` and the original
// raw metadata map — must keep restoring forever (a format migration must
// never orphan an existing rollback point).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/services/snapshot_serializer.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart'
    show BackupSchemaException;

void main() {
  late Map<String, Object?> writtenMetadata;
  late Map<String, Object?>? appliedSettings;

  SnapshotSerializer serializer({
    Map<String, Object?> metadata = const {'clips': <String, Object?>{}},
    Map<String, Object?> settings = const {'theme_mode': 1},
  }) {
    writtenMetadata = {};
    appliedSettings = null;
    return SnapshotSerializer(
      readMetadata: () async => metadata,
      dumpSettings: () async => settings,
      writeMetadata: (m) async => writtenMetadata = m,
      applySettings: (s) async => appliedSettings = s,
    );
  }

  Map<String, dynamic> decode(Uint8List bytes) =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

  group('dumpAll', () {
    test('wraps metadata + settings in the fleet BackupEnvelope', () async {
      final bytes = await serializer(
        metadata: {
          'clips': {
            '2026-01-01': [
              {'id': 'c1'}
            ]
          }
        },
        settings: {'theme_mode': 2},
      ).dumpAll();

      final envelope = decode(bytes);
      expect(envelope['app'], 'punctumtemporis');
      expect(envelope['schemaVersion'], 2);
      expect(DateTime.tryParse(envelope['createdAt'] as String), isNotNull,
          reason: 'preview/staleness copy needs the createdAt stamp');
      final payload = envelope['payload'] as Map<String, dynamic>;
      expect((payload['metadata'] as Map)['clips'], isNotEmpty);
      expect((payload['settings'] as Map)['theme_mode'], 2);
    });
  });

  group('dumpAll additive-keys law (old shipped parser compatibility)', () {
    // The OLD shipped build's snapshot parser (pre-envelope
    // backup_service.dart) had NO envelope branch. Its exact logic,
    // reconstructed here verbatim: branch on `snapshotVersion`, else
    // treat the WHOLE decoded map as raw metadata. New snapshots land in
    // old builds via the shared vault directory, so dumpAll output must
    // parse correctly under this logic forever.
    ({Object? metadata, Object? settings}) oldShippedParse(Uint8List bytes) {
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final metadata = decoded.containsKey('snapshotVersion')
          ? decoded['metadata']
          : decoded;
      final settings = decoded['settings'];
      return (metadata: metadata, settings: settings);
    }

    test('the OLD shipped parser reads correct metadata from new dumpAll',
        () async {
      final bytes = await serializer(
        metadata: {'marker': 'must-survive-downgrade'},
        settings: {'theme_mode': 2},
      ).dumpAll();

      final parsed = oldShippedParse(bytes);
      final metadata = parsed.metadata;
      expect(metadata, isA<Map<String, dynamic>>(),
          reason: 'old builds must not refuse new snapshots');
      expect((metadata as Map<String, dynamic>)['marker'],
          'must-survive-downgrade',
          reason: 'old parser must NOT see envelope keys as metadata — '
              'writing {app, schemaVersion, createdAt, payload} over '
              'metadata.json destroys the journal index');
      expect(metadata.containsKey('payload'), isFalse,
          reason: 'envelope keys leaking into metadata is the exact bug');
      expect((parsed.settings as Map<String, dynamic>)['theme_mode'], 2,
          reason: 'old parser reads settings at top level');
    });

    test('dumpAll emits legacy top-level keys alongside the envelope keys',
        () async {
      final map = decode(await serializer(
        metadata: {'marker': 'both-shapes'},
        settings: {'theme_mode': 3},
      ).dumpAll());

      // Envelope keys (the NEW parser branches on schemaVersion first).
      expect(map['app'], 'punctumtemporis');
      expect(map['schemaVersion'], 2);
      // Legacy composite keys (what the OLD parser branches on).
      expect(map['snapshotVersion'], 2);
      expect((map['metadata'] as Map<String, dynamic>)['marker'],
          'both-shapes');
      expect((map['settings'] as Map<String, dynamic>)['theme_mode'], 3);
    });
  });

  group('restoreAll', () {
    test('round-trips its own dumpAll output', () async {
      final s = serializer(
        metadata: {'marker': 'pre-mistake'},
        settings: {'theme_mode': 1},
      );
      final bytes = await s.dumpAll();
      await s.restoreAll(bytes);
      expect(writtenMetadata['marker'], 'pre-mistake');
      expect(appliedSettings!['theme_mode'], 1);
    });

    test('legacy v2 composite {snapshotVersion, metadata, settings} restores',
        () async {
      final s = serializer();
      await s.restoreAll(Uint8List.fromList(utf8.encode(jsonEncode({
        'snapshotVersion': 2,
        'metadata': {'marker': 'legacy-composite'},
        'settings': {'theme_mode': 3},
      }))));
      expect(writtenMetadata['marker'], 'legacy-composite');
      expect(appliedSettings!['theme_mode'], 3);
    });

    test('legacy raw metadata map restores with no settings applied',
        () async {
      final s = serializer();
      await s.restoreAll(Uint8List.fromList(
          utf8.encode(jsonEncode({'marker': 'legacy-raw'}))));
      expect(writtenMetadata['marker'], 'legacy-raw');
      expect(appliedSettings, isNull,
          reason: 'pre-composite snapshots never carried settings');
    });

    test('garbage bytes are refused before anything is written', () async {
      final s = serializer();
      await expectLater(
          s.restoreAll(Uint8List.fromList([0xFF, 0x00])),
          throwsA(isA<FormatException>()));
      expect(writtenMetadata, isEmpty);
      expect(appliedSettings, isNull);
    });

    test("another app's envelope is refused", () async {
      final s = serializer();
      await expectLater(
          s.restoreAll(Uint8List.fromList(utf8.encode(jsonEncode({
            'app': 'sundial',
            'schemaVersion': 1,
            'payload': {
              'metadata': {'marker': 'not-ours'}
            },
          })))),
          throwsA(isA<FormatException>()));
      expect(writtenMetadata, isEmpty);
    });

    test('a future schemaVersion is refused as BackupSchemaException',
        () async {
      final s = serializer();
      await expectLater(
          s.restoreAll(Uint8List.fromList(utf8.encode(jsonEncode({
            'app': 'punctumtemporis',
            'schemaVersion': 999,
            'payload': {'metadata': <String, Object?>{}},
          })))),
          throwsA(isA<BackupSchemaException>()));
      expect(writtenMetadata, isEmpty);
    });

    test('an envelope whose payload lacks a metadata map is refused',
        () async {
      final s = serializer();
      await expectLater(
          s.restoreAll(Uint8List.fromList(utf8.encode(jsonEncode({
            'app': 'punctumtemporis',
            'schemaVersion': 2,
            'payload': {'metadata': 'not a map'},
          })))),
          throwsA(isA<FormatException>()));
      expect(writtenMetadata, isEmpty);
    });
  });

  group('describeBackup', () {
    test('describes its own dumpAll output', () async {
      final s = serializer();
      final manifest = await s.describeBackup(await s.dumpAll());
      expect(manifest.appId, 'punctumtemporis');
      expect(manifest.schemaVersion, 2);
      expect(manifest.createdAt, isNotNull);
    });

    test('throws exactly what restoreAll would refuse', () async {
      final s = serializer();
      await expectLater(
          s.describeBackup(Uint8List.fromList([0xFF, 0x00])),
          throwsA(isA<FormatException>()));
    });
  });
}

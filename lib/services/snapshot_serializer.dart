import 'dart:convert';
import 'dart:typed_data';

import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart'
    show
        BackupEnvelope,
        BackupManifest,
        BackupSerializer,
        PreviewableBackupSerializer;

/// The result of decoding a vault snapshot, whatever its generation:
/// the metadata map that becomes the live `metadata.json`, plus the
/// allowlisted settings the snapshot carried (null for pre-composite
/// snapshots, which never had any).
class ParsedSnapshot {
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? settings;
  const ParsedSnapshot({required this.metadata, required this.settings});
}

/// PT's vault-snapshot codec on the fleet-standard [BackupEnvelope]
/// (C2-backup): new snapshots are wrapped `{app, schemaVersion, createdAt,
/// payload: {metadata, settings}}` instead of the hand-rolled composite the
/// app used to write. Reading stays tolerant forever — both legacy on-disk
/// shapes (the v2 composite `{snapshotVersion, metadata, settings}` and the
/// original raw metadata map) keep restoring, because a format migration
/// must never orphan an existing rollback point.
///
/// File/prefs plumbing is injected as callbacks: [BackupService] stays the
/// owner of where metadata lives and how settings are applied; this class
/// owns only the wire shape and its validation.
class SnapshotSerializer
    implements BackupSerializer, PreviewableBackupSerializer {
  SnapshotSerializer({
    required this.readMetadata,
    required this.dumpSettings,
    required this.writeMetadata,
    required this.applySettings,
  });

  static const String appId = 'punctumtemporis';

  /// The composite (metadata + settings) snapshot generation — the same
  /// "2" the legacy `snapshotVersion` field carried, now as the envelope's
  /// `schemaVersion`.
  static const int schemaVersion = 2;

  final Future<Map<String, Object?>> Function() readMetadata;
  final Future<Map<String, Object?>> Function() dumpSettings;
  final Future<void> Function(Map<String, dynamic> metadata) writeMetadata;
  final Future<void> Function(Map<String, dynamic> settings) applySettings;

  /// Additive-keys law: new snapshots carry the fleet envelope keys AND
  /// the legacy v2 composite keys (`snapshotVersion`/`metadata`/
  /// `settings`) at top level. The OLD shipped build's snapshot parser
  /// has no envelope branch — it branches on `snapshotVersion`, else
  /// treats the whole map as raw metadata, so an envelope-only snapshot
  /// would make it write `{app, schemaVersion, createdAt, payload}`
  /// garbage over `metadata.json`. Emitting both shapes means the old
  /// parser sees exactly the legacy composite it expects, while [parse]
  /// branches on the envelope keys first.
  @override
  Future<Uint8List> dumpAll() async {
    final metadata = await readMetadata();
    final settings = await dumpSettings();
    final envelope = jsonDecode(utf8.decode(BackupEnvelope.wrap(
      appId: appId,
      schemaVersion: schemaVersion,
      createdAt: DateTime.now(),
      payload: {'metadata': metadata, 'settings': settings},
    ))) as Map<String, dynamic>;
    envelope['snapshotVersion'] = schemaVersion;
    envelope['metadata'] = metadata;
    envelope['settings'] = settings;
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  @override
  Future<void> restoreAll(Uint8List plaintext) async {
    final parsed = parse(plaintext);
    await writeMetadata(parsed.metadata);
    final settings = parsed.settings;
    if (settings != null) await applySettings(settings);
  }

  @override
  Future<BackupManifest> describeBackup(Uint8List plaintext) async {
    parse(plaintext); // throw exactly what restoreAll would refuse
    return BackupEnvelope.describe(plaintext);
  }

  /// Decodes and validates any snapshot generation WITHOUT writing:
  /// envelope-wrapped (validated via [BackupEnvelope.unwrap] — wrong app
  /// and future schema reject), legacy v2 composite, or legacy raw
  /// metadata. Throws [FormatException] / `BackupSchemaException` for
  /// anything unrestorable.
  static ParsedSnapshot parse(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object {
      throw const FormatException('Snapshot is not valid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Snapshot is not a JSON object');
    }

    // Envelope-wrapped (the only shape that carries schemaVersion).
    if (decoded.containsKey('schemaVersion')) {
      final unwrapped = BackupEnvelope.unwrap(
        bytes,
        expectedAppId: appId,
        currentSchemaVersion: schemaVersion,
      );
      final metadata = unwrapped.payload['metadata'];
      if (metadata is! Map<String, dynamic>) {
        throw const FormatException('Snapshot payload has no metadata map');
      }
      final settings = unwrapped.payload['settings'];
      return ParsedSnapshot(
        metadata: metadata,
        settings: settings is Map<String, dynamic> ? settings : null,
      );
    }

    // Legacy v2 composite: {snapshotVersion, metadata, settings}.
    if (decoded.containsKey('snapshotVersion')) {
      final metadata = decoded['metadata'];
      if (metadata is! Map<String, dynamic>) {
        throw const FormatException('Snapshot composite has no metadata map');
      }
      final settings = decoded['settings'];
      return ParsedSnapshot(
        metadata: metadata,
        settings: settings is Map<String, dynamic> ? settings : null,
      );
    }

    // Legacy raw metadata map (pre-composite; never carried settings).
    return ParsedSnapshot(metadata: decoded, settings: null);
  }
}

/// The person-name path guard, shared by every site that interpolates a
/// name into `'$facesDir/$name.jpg'` (StorageService.saveFaceImage /
/// getFaceImagePath, BackupService.createBackup / getBackupSize, and the
/// restore-boundary sanitizer in BackupService).
///
/// A face reference image is keyed by the person's display name, so the name
/// must be a plain basename — no separators, traversal, quotes, or control
/// characters — or it could read or write files outside the faces dir
/// (a `'../secret'` key would pack a foreign file into a shared backup).
library;

/// Whether [name] is safe to use as the basename of a face image file.
bool isSafePersonName(String name) {
  return name.isNotEmpty &&
      !name.contains('/') &&
      !name.contains('\\') &&
      !name.contains('..') &&
      !name.contains('"') &&
      !name.contains('\n') &&
      !name.contains('\r');
}

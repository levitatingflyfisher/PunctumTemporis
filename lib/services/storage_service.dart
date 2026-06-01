import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:home_widget/home_widget.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/clip.dart';
import '../platform/file_storage.dart';
import '../utils/date_format_util.dart';

class StorageService {
  final SharedPreferences _prefs;

  String _clipsDir = '';
  String _thumbnailsDir = '';
  String _compiledDir = '';
  late String _facesDir;
  late String _metadataPath;

  final _uuid = const Uuid();

  Map<String, List<Clip>> _clips = {};
  List<Compilation> _compilations = [];

  StorageService(this._prefs);

  static const _themeKey = 'theme_mode';
  static const _accentKey = 'accent_color';
  static const _crtKey = 'crt_effects';
  static const _dateFormatKey = 'date_format';
  static const _captureLocationKey = 'capture_location';
  static const _includeLocationOverlayKey = 'include_location_overlay';
  static const _clipsMigratedKey = 'clips_migrated_v2';
  static const _visualStyleKey = 'visual_style';
  static const _pinnedTagsKey = 'pinned_tags';
  static const _pinnedLocationsKey = 'pinned_locations';

  /// Initialize storage directories
  Future<void> initialize() async {
    final appDoc = await FileStorage.appDocDir();

    _clipsDir = '$appDoc/clips';
    _thumbnailsDir = '$appDoc/thumbnails';
    _facesDir = '$appDoc/faces';
    _metadataPath = '$appDoc/metadata.json';

    // Compilations: public Movies dir on Android, app doc fallback (or web)
    final externalBase = await FileStorage.externalStorageDir();
    if (externalBase != null) {
      final basePath = externalBase.split('Android')[0];
      _compiledDir = '${basePath}Movies/OneSecondADay/compilations';
    } else {
      _compiledDir = '$appDoc/compiled';
    }

    await FileStorage.ensureDir(_clipsDir);
    await FileStorage.ensureDir(_thumbnailsDir);
    await FileStorage.ensureDir(_compiledDir);

    await _loadMetadata();
    await _migrateClipsToPrivate();
  }

  /// One-time migration: move clips from old public dir to app-private dir
  Future<void> _migrateClipsToPrivate() async {
    if (kIsWeb) return; // Migration is Android-only
    if (_prefs.getBool(_clipsMigratedKey) == true) return;

    final externalBase = await FileStorage.externalStorageDir();
    if (externalBase == null) {
      await _prefs.setBool(_clipsMigratedKey, true);
      return;
    }

    final basePath = externalBase.split('Android')[0];
    final oldClipsDir = '${basePath}Movies/OneSecondADay/clips';
    if (!await FileStorage.dirExists(oldClipsDir)) {
      await _prefs.setBool(_clipsMigratedKey, true);
      return;
    }

    bool migrated = false;
    for (final date in _clips.keys.toList()) {
      final clipList = _clips[date]!;
      for (var i = 0; i < clipList.length; i++) {
        final clip = clipList[i];
        if (clip.filePath.startsWith(oldClipsDir)) {
          if (await FileStorage.exists(clip.filePath)) {
            final newPath = '$_clipsDir/${clip.filePath.split('/').last}';
            await FileStorage.copyFile(clip.filePath, newPath);
            await FileStorage.deleteFile(clip.filePath);
            clipList[i] = clip.copyWith(filePath: newPath);
            migrated = true;
          }
        }
      }
    }

    if (migrated) await _saveMetadata();
    await _prefs.setBool(_clipsMigratedKey, true);
  }

  Future<void> _loadMetadata() async {
    if (await FileStorage.exists(_metadataPath)) {
      try {
        final content = await FileStorage.readString(_metadataPath);
        if (content == null) return;
        final data = jsonDecode(content) as Map<String, dynamic>;

        if (data['clips'] != null) {
          final clipsData = data['clips'] as Map<String, dynamic>;
          _clips = {};
          for (final entry in clipsData.entries) {
            final value = entry.value;
            if (value is List) {
              _clips[entry.key] = value
                  .map((e) => Clip.fromJson(e as Map<String, dynamic>))
                  .toList();
            } else if (value is Map) {
              _clips[entry.key] = [
                Clip.fromJson(value as Map<String, dynamic>)
              ];
            }
          }
        }

        if (data['compilations'] != null) {
          _compilations = (data['compilations'] as List)
              .map((e) => Compilation.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        if (data['knownPeople'] != null) {
          final peopleData = data['knownPeople'] as Map<String, dynamic>;
          _knownPeople = peopleData.map((name, embeddings) => MapEntry(
                name,
                (embeddings as List)
                    .map((e) =>
                        (e as List).map((v) => (v as num).toDouble()).toList())
                    .toList(),
              ));
        }
      } catch (e) {
        debugPrint('Error loading metadata: $e');
        _clips = {};
        _compilations = [];
      }
    }
  }

  Future<void> _saveMetadata() async {
    final data = {
      'clips': _clips.map(
          (key, value) => MapEntry(key, value.map((c) => c.toJson()).toList())),
      'compilations': _compilations.map((e) => e.toJson()).toList(),
      'knownPeople': _knownPeople,
    };
    await FileStorage.writeString(_metadataPath, jsonEncode(data));
  }

  String get clipsPath => _clipsDir;
  String get thumbnailsPath => _thumbnailsDir;
  String get compiledPath => _compiledDir;

  String generateId() => _uuid.v4();

  String getClipPath(String clipId) => '$_clipsDir/$clipId.mp4';
  String getThumbnailPath(String clipId) => '$_thumbnailsDir/$clipId.jpg';

  /// Generate compilation path using date range + timestamp for unique filenames
  String getCompilationPath(String startDate, String endDate) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$_compiledDir/${startDate}_to_${endDate}_$timestamp.mp4';
  }

  Map<String, List<Clip>> get clips => Map.unmodifiable(_clips);

  List<Clip> getClipsForDate(String date) => _clips[date] ?? [];

  Clip? getFirstClipForDate(String date) {
    final list = _clips[date];
    return (list != null && list.isNotEmpty) ? list.first : null;
  }

  int clipCountForDate(String date) => _clips[date]?.length ?? 0;

  bool hasClipForDate(String date) => _clips.containsKey(date);

  Future<void> addClip(Clip clip) async {
    _clips.putIfAbsent(clip.date, () => []);
    _clips[clip.date]!.add(clip);
    await _saveMetadata();
    _updateWidget();
  }

  void _updateWidget() {
    if (kIsWeb) return;
    try {
      final streak = getCurrentStreak();
      final today = DateFormatUtil.format(DateTime.now(), DateFormatOption.isoDate);
      final capturedToday = _clips.containsKey(today);
      HomeWidget.saveWidgetData<int>('streak', streak);
      HomeWidget.saveWidgetData<bool>('captured_today', capturedToday);
      HomeWidget.updateWidget(
        name: 'OneSecondWidget',
        qualifiedAndroidName: 'com.example.one_second_a_day.OneSecondWidget',
      );
    } catch (_) {}
  }

  Future<void> updateClip(Clip clip) async {
    final list = _clips[clip.date];
    if (list != null) {
      final index = list.indexWhere((c) => c.id == clip.id);
      if (index >= 0) {
        list[index] = clip;
        await _saveMetadata();
      }
    }
  }

  Future<void> deleteClip(String clipId) async {
    for (final date in _clips.keys.toList()) {
      final list = _clips[date]!;
      final index = list.indexWhere((c) => c.id == clipId);
      if (index >= 0) {
        final clip = list[index];
        await FileStorage.deleteFile(clip.filePath);
        if (clip.thumbnailPath != null) {
          await FileStorage.deleteFile(clip.thumbnailPath!);
        }
        list.removeAt(index);
        if (list.isEmpty) _clips.remove(date);
        await _saveMetadata();
        return;
      }
    }
  }

  List<Clip> getClipsInRange(String startDate, String endDate) {
    return _clips.entries
        .where((e) =>
            e.key.compareTo(startDate) >= 0 && e.key.compareTo(endDate) <= 0)
        .expand((e) => e.value)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Clip> getClipsForMonth(int year, int month) {
    final monthStr = month.toString().padLeft(2, '0');
    final prefix = '$year-$monthStr';
    return _clips.entries
        .where((e) => e.key.startsWith(prefix))
        .expand((e) => e.value)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Set<String> get datesWithClips => _clips.keys.toSet();

  Set<String> get allTags {
    final tags = <String>{};
    for (final list in _clips.values) {
      for (final clip in list) {
        tags.addAll(clip.tags);
      }
    }
    return tags;
  }

  Set<String> get allLocations {
    final locations = <String>{};
    for (final list in _clips.values) {
      for (final clip in list) {
        if (clip.locationLabel != null && clip.locationLabel!.isNotEmpty) {
          locations.add(clip.locationLabel!);
        }
      }
    }
    return locations;
  }

  Set<String> get pinnedTags =>
      Set.unmodifiable(_prefs.getStringList(_pinnedTagsKey)?.toSet() ?? {});

  Set<String> get pinnedLocations =>
      Set.unmodifiable(_prefs.getStringList(_pinnedLocationsKey)?.toSet() ?? {});

  Set<String> get allTagsWithPinned => {...allTags, ...pinnedTags};
  Set<String> get allLocationsWithPinned => {...allLocations, ...pinnedLocations};

  Future<void> pinTag(String tag) async =>
      await _prefs.setStringList(_pinnedTagsKey, [...pinnedTags, tag]);

  Future<void> unpinTag(String tag) async => await _prefs.setStringList(
      _pinnedTagsKey, pinnedTags.where((t) => t != tag).toList());

  Future<void> pinLocation(String location) async =>
      await _prefs.setStringList(_pinnedLocationsKey, [...pinnedLocations, location]);

  Future<void> unpinLocation(String location) async => await _prefs.setStringList(
      _pinnedLocationsKey, pinnedLocations.where((l) => l != location).toList());

  List<Clip> getClipsInRangeFiltered(
    String startDate,
    String endDate, {
    Set<String> tagFilter = const {},
    Set<String> locationFilter = const {},
    Set<int> weekdayFilter = const {},
  }) {
    var clips = _clips.entries
        .where((e) =>
            e.key.compareTo(startDate) >= 0 && e.key.compareTo(endDate) <= 0)
        .expand((e) => e.value);

    if (tagFilter.isNotEmpty) {
      clips = clips.where((c) => c.tags.any((t) => tagFilter.contains(t)));
    }
    if (locationFilter.isNotEmpty) {
      clips = clips.where((c) =>
          c.locationLabel != null && locationFilter.contains(c.locationLabel));
    }
    if (weekdayFilter.isNotEmpty) {
      clips = clips.where((c) {
        final date = DateTime.parse(c.date);
        return weekdayFilter.contains(date.weekday);
      });
    }

    return clips.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Compilation> get compilations => List.unmodifiable(_compilations);

  Future<void> addCompilation(Compilation compilation) async {
    _compilations.add(compilation);
    await _saveMetadata();
    if (!kIsWeb) {
      await MediaScanner.loadMedia(path: compilation.filePath);
    }
  }

  Future<void> deleteCompilation(String id) async {
    final index = _compilations.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final compilation = _compilations[index];
      await FileStorage.deleteFile(compilation.filePath);
      _compilations.removeAt(index);
      await _saveMetadata();
    }
  }

  int get totalClips => _clips.values.fold(0, (sum, list) => sum + list.length);

  int getCurrentStreak() {
    if (_clips.isEmpty) return 0;
    var streak = 0;
    var date = DateTime.now();
    // If today has no clip yet, start counting from yesterday so a
    // multi-day streak is not broken before the day's clip is recorded.
    if (!_clips.containsKey(DateFormatUtil.format(date, DateFormatOption.isoDate))) {
      date = date.subtract(const Duration(days: 1));
    }
    while (true) {
      final dateStr = DateFormatUtil.format(date, DateFormatOption.isoDate);
      if (_clips.containsKey(dateStr)) {
        streak++;
        date = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  int getLongestStreak() {
    if (_clips.isEmpty) return 0;
    final dates = _clips.keys.toList()..sort();
    var longest = 1;
    var current = 1;
    for (var i = 1; i < dates.length; i++) {
      final prev = DateTime.parse(dates[i - 1]);
      final curr = DateTime.parse(dates[i]);
      final diff = curr.difference(prev).inDays;
      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  int getThemeMode() => _prefs.getInt(_themeKey) ?? 0;
  Future<void> setThemeMode(int mode) => _prefs.setInt(_themeKey, mode);

  int getAccentColor() => _prefs.getInt(_accentKey) ?? 0xFF00FF00;
  Future<void> setAccentColor(int color) => _prefs.setInt(_accentKey, color);

  bool getCrtEffects() => _prefs.getBool(_crtKey) ?? true;
  Future<void> setCrtEffects(bool enabled) => _prefs.setBool(_crtKey, enabled);

  String getDateFormat() => _prefs.getString(_dateFormatKey) ?? 'ddMmmYyyy';
  Future<void> setDateFormat(String key) =>
      _prefs.setString(_dateFormatKey, key);

  bool getCaptureLocation() => _prefs.getBool(_captureLocationKey) ?? true;
  Future<void> setCaptureLocation(bool enabled) =>
      _prefs.setBool(_captureLocationKey, enabled);

  bool getIncludeLocationOverlay() =>
      _prefs.getBool(_includeLocationOverlayKey) ?? true;
  Future<void> setIncludeLocationOverlay(bool enabled) =>
      _prefs.setBool(_includeLocationOverlayKey, enabled);

  String getVisualStyle() => _prefs.getString(_visualStyleKey) ?? 'hearth';
  Future<void> setVisualStyle(String style) =>
      _prefs.setString(_visualStyleKey, style);

  Map<String, List<List<double>>> _knownPeople = {};
  Map<String, List<List<double>>> get knownPeople =>
      Map.unmodifiable(_knownPeople);

  Future<void> addPersonEmbedding(String name, List<double> embedding) async {
    _knownPeople.putIfAbsent(name, () => []);
    if (_knownPeople[name]!.length < 5) {
      _knownPeople[name]!.add(embedding);
    }
    await _saveMetadata();
  }

  Future<void> removePerson(String name) async {
    _knownPeople.remove(name);
    await _saveMetadata();
  }

  List<String> get knownPeopleNames => _knownPeople.keys.toList()..sort();

  Set<String> uniqueDatesInRange(String startDate, String endDate) {
    return _clips.keys
        .where((d) => d.compareTo(startDate) >= 0 && d.compareTo(endDate) <= 0)
        .toSet();
  }

  int getStreakInRange(String startDate, String endDate) {
    final dates = _clips.keys
        .where((d) => d.compareTo(startDate) >= 0 && d.compareTo(endDate) <= 0)
        .toList()
      ..sort();
    if (dates.isEmpty) return 0;
    var longest = 1;
    var current = 1;
    for (var i = 1; i < dates.length; i++) {
      final prev = DateTime.parse(dates[i - 1]);
      final curr = DateTime.parse(dates[i]);
      if (curr.difference(prev).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  Map<String, int> getLocationCountsInRange(String startDate, String endDate) {
    final counts = <String, int>{};
    for (final entry in _clips.entries) {
      if (entry.key.compareTo(startDate) < 0 ||
          entry.key.compareTo(endDate) > 0) continue;
      for (final clip in entry.value) {
        if (clip.locationLabel != null && clip.locationLabel!.isNotEmpty) {
          counts[clip.locationLabel!] = (counts[clip.locationLabel!] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  Map<String, int> getTagCountsInRange(String startDate, String endDate) {
    final counts = <String, int>{};
    for (final entry in _clips.entries) {
      if (entry.key.compareTo(startDate) < 0 ||
          entry.key.compareTo(endDate) > 0) continue;
      for (final clip in entry.value) {
        for (final tag in clip.tags) {
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  Map<String, int> getFaceCountsInRange(String startDate, String endDate) {
    final counts = <String, int>{};
    for (final entry in _clips.entries) {
      if (entry.key.compareTo(startDate) < 0 ||
          entry.key.compareTo(endDate) > 0) continue;
      for (final clip in entry.value) {
        for (final face in clip.detectedFaces) {
          counts[face] = (counts[face] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderTimeKey = 'reminder_time';

  bool getReminderEnabled() => _prefs.getBool(_reminderEnabledKey) ?? false;
  Future<void> setReminderEnabled(bool enabled) =>
      _prefs.setBool(_reminderEnabledKey, enabled);

  TimeOfDay getReminderTime() {
    final str = _prefs.getString(_reminderTimeKey) ?? '20:00';
    final parts = str.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> setReminderTime(TimeOfDay time) {
    final str =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return _prefs.setString(_reminderTimeKey, str);
  }

  Future<void> replaceClipFile(String clipId, String newFilePath,
      {double? newDuration}) async {
    for (final date in _clips.keys) {
      final list = _clips[date]!;
      final index = list.indexWhere((c) => c.id == clipId);
      if (index >= 0) {
        final clip = list[index];
        if (await FileStorage.exists(newFilePath)) {
          await FileStorage.copyFile(newFilePath, clip.filePath);
          if (newFilePath != clip.filePath) {
            await FileStorage.deleteFile(newFilePath);
          }
          if (newDuration != null) {
            list[index] = clip.copyWith(duration: newDuration);
          }
          await _saveMetadata();
        }
        return;
      }
    }
  }

  Future<void> reorderClips(String date, List<String> clipIdsInOrder) async {
    final list = _clips[date];
    if (list == null) return;
    final reordered = <Clip>[];
    for (final id in clipIdsInOrder) {
      final clip = list.where((c) => c.id == id).firstOrNull;
      if (clip == null) continue; // skip stale IDs rather than duplicating
      reordered.add(clip);
    }
    for (final clip in list) {
      if (!clipIdsInOrder.contains(clip.id)) reordered.add(clip);
    }
    _clips[date] = reordered;
    await _saveMetadata();
  }

  static const _celebratedMilestonesKey = 'celebrated_milestones';
  static const _onboardingCompleteKey = 'onboarding_complete';

  Set<int> getCelebratedMilestones() {
    final list = _prefs.getStringList(_celebratedMilestonesKey) ?? [];
    return list.map((s) => int.tryParse(s) ?? 0).where((v) => v > 0).toSet();
  }

  Future<void> addCelebratedMilestone(int days) async {
    final milestones = getCelebratedMilestones();
    milestones.add(days);
    await _prefs.setStringList(
      _celebratedMilestonesKey,
      milestones.map((m) => m.toString()).toList(),
    );
  }

  bool getOnboardingComplete() =>
      _prefs.getBool(_onboardingCompleteKey) ?? false;
  Future<void> setOnboardingComplete(bool complete) =>
      _prefs.setBool(_onboardingCompleteKey, complete);

  /// Returns the face reference image path, or null if not found.
  String? getFaceImagePath(String name) {
    final path = '$_facesDir/$name.jpg';
    if (FileStorage.existsSync(path)) return path;
    return null;
  }

  /// Save a cropped face image as a reference for a named person.
  Future<void> saveFaceImage(
      String name, String sourceImagePath, Rect boundingBox) async {
    try {
      await FileStorage.ensureDir(_facesDir);
      final destPath = '$_facesDir/$name.jpg';
      await FileStorage.copyFile(sourceImagePath, destPath);
    } catch (e) {
      debugPrint('Failed to save face image: $e');
    }
  }

  /// For tests only — directly seeds the in-memory clip map.
  @visibleForTesting
  void setClipsForTest(Map<String, List<Clip>> clips) {
    _clips = Map.from(clips);
  }
}

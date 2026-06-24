import 'dart:convert';

// Sentinel used by Clip.copyWith to distinguish "not provided" from
// "explicitly null". Must be a top-level const so it qualifies as a
// compile-time constant (required for default parameter values).
const _sentinel = Object();

enum ClipType {
  video,
  photo,
  imported,
}

class Clip {
  final String id;
  final String date; // YYYY-MM-DD format
  final String filePath;
  final String? thumbnailPath;
  final ClipType type;
  final DateTime createdAt;
  final DateTime? capturedAt;
  final String? notes;
  final double? duration; // in seconds
  final String? exifDate; // YYYY-MM-DD original media creation date
  final List<String> tags;
  final double? latitude;
  final double? longitude;
  final String? locationLabel; // e.g. "Paris" or "Brooklyn, NY"
  final List<String> detectedFaces; // person names from face recognition

  bool get hasDateMismatch => exifDate != null && exifDate != date;

  Clip({
    required this.id,
    required this.date,
    required this.filePath,
    this.thumbnailPath,
    required this.type,
    required this.createdAt,
    this.capturedAt,
    this.notes,
    this.duration,
    this.exifDate,
    this.tags = const [],
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.detectedFaces = const [],
  });

  Clip copyWith({
    String? id,
    String? date,
    String? filePath,
    Object? thumbnailPath = _sentinel,
    ClipType? type,
    DateTime? createdAt,
    Object? capturedAt = _sentinel,
    Object? notes = _sentinel,
    Object? duration = _sentinel,
    Object? exifDate = _sentinel,
    List<String>? tags,
    Object? latitude = _sentinel,
    Object? longitude = _sentinel,
    Object? locationLabel = _sentinel,
    List<String>? detectedFaces,
  }) {
    return Clip(
      id: id ?? this.id,
      date: date ?? this.date,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath == _sentinel ? this.thumbnailPath : thumbnailPath as String?,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      capturedAt: capturedAt == _sentinel ? this.capturedAt : capturedAt as DateTime?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      duration: duration == _sentinel ? this.duration : duration as double?,
      exifDate: exifDate == _sentinel ? this.exifDate : exifDate as String?,
      tags: tags ?? this.tags,
      latitude: latitude == _sentinel ? this.latitude : latitude as double?,
      longitude: longitude == _sentinel ? this.longitude : longitude as double?,
      locationLabel: locationLabel == _sentinel ? this.locationLabel : locationLabel as String?,
      detectedFaces: detectedFaces ?? this.detectedFaces,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'filePath': filePath,
      'thumbnailPath': thumbnailPath,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'capturedAt': capturedAt?.toIso8601String(),
      'notes': notes,
      'duration': duration,
      'exifDate': exifDate,
      'tags': tags,
      'latitude': latitude,
      'longitude': longitude,
      'locationLabel': locationLabel,
      'detectedFaces': detectedFaces,
    };
  }

  factory Clip.fromJson(Map<String, dynamic> json) {
    return Clip(
      id: json['id'] as String,
      date: json['date'] as String,
      filePath: json['filePath'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      type: ClipType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ClipType.video,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      capturedAt: json['capturedAt'] != null
          ? DateTime.parse(json['capturedAt'] as String)
          : null,
      notes: json['notes'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
      exifDate: json['exifDate'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationLabel: json['locationLabel'] as String?,
      detectedFaces: (json['detectedFaces'] as List?)?.cast<String>() ?? [],
    );
  }

  @override
  String toString() {
    return 'Clip(id: $id, date: $date, type: ${type.name})';
  }
}

class Compilation {
  final String id;
  final String title;
  final String filePath;
  final List<String> clipIds;
  final DateTime createdAt;
  final String? startDate;
  final String? endDate;
  final double? duration;

  Compilation({
    required this.id,
    required this.title,
    required this.filePath,
    required this.clipIds,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'clipIds': clipIds,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate,
      'endDate': endDate,
      'duration': duration,
    };
  }

  factory Compilation.fromJson(Map<String, dynamic> json) {
    return Compilation(
      id: json['id'] as String,
      title: json['title'] as String,
      filePath: json['filePath'] as String,
      clipIds: (json['clipIds'] as List).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
    );
  }
}

class AudioSegment {
  final String filePath;
  final String fileName;
  final double startTimeInCompilation; // seconds from start of compiled video
  final double audioOffset; // seconds into the audio file to start from
  final double?
      duration; // duration to play (null = until end of audio or compilation)
  final double volume; // 0.0 to 1.0

  AudioSegment({
    required this.filePath,
    required this.fileName,
    this.startTimeInCompilation = 0,
    this.audioOffset = 0,
    this.duration,
    this.volume = 0.3,
  });

  AudioSegment copyWith({
    String? filePath,
    String? fileName,
    double? startTimeInCompilation,
    double? audioOffset,
    double? duration,
    double? volume,
  }) {
    return AudioSegment(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      startTimeInCompilation:
          startTimeInCompilation ?? this.startTimeInCompilation,
      audioOffset: audioOffset ?? this.audioOffset,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
    );
  }
}

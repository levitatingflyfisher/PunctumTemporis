import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class _City {
  final String name;
  final double lat;
  final double lon;
  final String cc;

  _City(this.name, this.lat, this.lon, this.cc);
}

/// Fully offline reverse geocoder using bundled GeoNames cities15000 data.
/// Uses brute-force nearest-neighbor search (fast enough for ~33K cities).
class OfflineGeocoder {
  static OfflineGeocoder? _instance;
  List<_City>? _cities;
  bool _initialized = false;

  OfflineGeocoder._();

  static OfflineGeocoder get instance {
    _instance ??= OfflineGeocoder._();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final csv = await rootBundle.loadString('assets/data/cities.csv');
      final lines = csv.split('\n');
      _cities = [];

      // Skip header line
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // Parse CSV: name,lat,lon,cc
        // Handle names that might contain commas by finding fields from the right
        final lastComma = line.lastIndexOf(',');
        if (lastComma < 0) continue;
        final cc = line.substring(lastComma + 1);

        final beforeCc = line.substring(0, lastComma);
        final lonComma = beforeCc.lastIndexOf(',');
        if (lonComma < 0) continue;
        final lonStr = beforeCc.substring(lonComma + 1);

        final beforeLon = beforeCc.substring(0, lonComma);
        final latComma = beforeLon.lastIndexOf(',');
        if (latComma < 0) continue;
        final latStr = beforeLon.substring(latComma + 1);

        final name = beforeLon.substring(0, latComma);

        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (lat == null || lon == null) continue;

        _cities!.add(_City(name, lat, lon, cc));
      }

      _initialized = true;
      debugPrint('OfflineGeocoder: loaded ${_cities!.length} cities');
    } catch (e) {
      debugPrint('OfflineGeocoder init failed: $e');
      _cities = null;
    }
  }

  /// Look up nearest city to the given coordinates.
  /// Returns "City, CC" (e.g. "Paris, FR") or null if not initialized.
  String? lookup(double lat, double lon) {
    if (_cities == null || _cities!.isEmpty) return null;

    _City? best;
    double bestDist = double.infinity;

    for (final city in _cities!) {
      final dist = _haversineDistance(lat, lon, city.lat, city.lon);
      if (dist < bestDist) {
        bestDist = dist;
        best = city;
      }
    }

    if (best == null) return null;
    return '${best.name}, ${best.cc}';
  }

  /// Haversine distance in km between two lat/lon points.
  static double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * pi / 180;
}

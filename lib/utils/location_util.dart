import 'package:geolocator/geolocator.dart';
import '../services/offline_geocoder.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? label;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.label,
  });
}

class LocationUtil {
  /// Get current GPS position and reverse geocode to a city label.
  /// Returns null if permission denied or location unavailable.
  static Future<LocationResult?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      // Try getLastKnownPosition first as a fast fallback (available instantly)
      final lastKnown = await Geolocator.getLastKnownPosition();

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        // getCurrentPosition timed out or failed — fall back to last known
        position = lastKnown;
      }

      if (position == null) return null;

      final label =
          await _reverseGeocode(position.latitude, position.longitude);

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        label: label,
      );
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocode coordinates to a city/region label (fully offline).
  static Future<String?> reverseGeocodeLabel(
      double latitude, double longitude) async {
    return _reverseGeocode(latitude, longitude);
  }

  static Future<String?> _reverseGeocode(
      double latitude, double longitude) async {
    try {
      await OfflineGeocoder.instance.initialize();
      return OfflineGeocoder.instance.lookup(latitude, longitude);
    } catch (_) {
      return null;
    }
  }
}

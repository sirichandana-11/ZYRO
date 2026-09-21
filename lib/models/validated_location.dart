import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'coordinate.dart';

/// Quality-filtered, validated geospatial location model for ZYRO.
class ValidatedLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
  final double speedMps;
  final double headingDegrees;
  final bool isFresh;
  final bool isReliable;
  final bool isMocked;

  // Centralized Quality Thresholds
  static const double maxAcceptableAccuracyMeters = 35.0;
  static const int maxLocationAgeSeconds = 15;
  static const double maxReasonableSpeedMps = 45.0; // ~162 km/h
  static const double maxPlausibleJumpMeters = 500.0; // Without sufficient elapsed time

  const ValidatedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
    this.speedMps = 0.0,
    this.headingDegrees = 0.0,
    this.isFresh = true,
    this.isReliable = true,
    this.isMocked = false,
  });

  /// Validates a raw [Position] and checks kinematic plausibility against [previous].
  static ValidatedLocation? fromPosition(
    Position position, {
    ValidatedLocation? previous,
    DateTime? now,
  }) {
    // 1. Basic Coordinate validity (NaN, Infinity, Bounds, Null Island)
    if (!Coordinate.isValid(position.latitude, position.longitude)) {
      return null;
    }

    final currentTime = now ?? DateTime.now();
    final positionTime = position.timestamp;
    final int ageSeconds = currentTime.difference(positionTime).inSeconds.abs();
    final bool isFresh = ageSeconds <= maxLocationAgeSeconds;

    // 2. Accuracy Validation
    final double accuracy = position.accuracy;
    final bool isAccurate = accuracy > 0 && accuracy <= maxAcceptableAccuracyMeters;

    // 3. Kinematic Plausibility & Jump Protection
    bool isPlausible = true;
    if (previous != null) {
      final double distanceMeters = calculateDistanceMeters(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );

      final double timeDeltaSeconds =
          positionTime.difference(previous.timestamp).inMilliseconds.abs() / 1000.0;

      if (timeDeltaSeconds > 0.1) {
        final double calculatedSpeedMps = distanceMeters / timeDeltaSeconds;
        if (calculatedSpeedMps > maxReasonableSpeedMps && distanceMeters > 50.0) {
          // Flag impossible teleports: if jump is large (> 200m or > 2x speed limit), reject
          if (distanceMeters > 200.0 || calculatedSpeedMps > (maxReasonableSpeedMps * 2)) {
            isPlausible = false;
          } else if (accuracy > 15.0) {
            // Small jump with degraded accuracy
            isPlausible = false;
          }
        }
      } else if (distanceMeters > 30.0) {
        // High displacement with zero / near-zero time delta
        isPlausible = false;
      }
    }

    final bool isReliable = isFresh && isAccurate && isPlausible;

    return ValidatedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: accuracy,
      timestamp: positionTime,
      speedMps: position.speed >= 0 ? position.speed : 0.0,
      headingDegrees: position.heading >= 0 ? position.heading : 0.0,
      isFresh: isFresh,
      isReliable: isReliable,
      isMocked: position.isMocked,
    );
  }

  /// Calculates Haversine distance in meters between two coordinates.
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Alias for calculateDistanceMeters
  static double distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) =>
      calculateDistanceMeters(lat1, lon1, lat2, lon2);

  static double _degToRad(double deg) => deg * (pi / 180.0);

  /// Human-readable diagnostic description
  String toDiagnosticString() {
    return 'Lat: ${latitude.toStringAsFixed(5)}, Lng: ${longitude.toStringAsFixed(5)} | '
        'Acc: ${accuracyMeters.toStringAsFixed(1)}m | '
        'Speed: ${speedMps.toStringAsFixed(1)}m/s | '
        'Heading: ${headingDegrees.toStringAsFixed(0)}° | '
        'Fresh: $isFresh | Reliable: $isReliable';
  }

  @override
  String toString() =>
      'ValidatedLocation($latitude, $longitude, ±${accuracyMeters.toStringAsFixed(1)}m)';
}

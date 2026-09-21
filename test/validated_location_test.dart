import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zyro/models/validated_location.dart';

void main() {
  group('ValidatedLocation & Kinematic Jump Protection Tests', () {
    test('Haversine distance calculation matches expected geographic distances', () {
      // Coordinates:
      // Point A: Lendi Institute of Eng & Tech (18.0674, 83.3980)
      // Point B: Vizianagaram Junction (18.1067, 83.3956)
      // Distance is approximately 4.37 km (4370 meters)
      final distance = ValidatedLocation.distanceMeters(
        18.0674,
        83.3980,
        18.1067,
        83.3956,
      );

      expect(distance, greaterThan(4300));
      expect(distance, lessThan(4500));
    });

    test('Zero distance between identical coordinates', () {
      final distance = ValidatedLocation.distanceMeters(
        18.0674,
        83.3980,
        18.0674,
        83.3980,
      );
      expect(distance, closeTo(0.0, 0.001));
    });

    test('Valid position within accuracy thresholds passes validation', () {
      final now = DateTime.now();
      final pos = Position(
        latitude: 18.0674,
        longitude: 83.3980,
        timestamp: now,
        accuracy: 8.5,
        altitude: 50.0,
        altitudeAccuracy: 1.0,
        heading: 90.0,
        headingAccuracy: 1.0,
        speed: 12.0,
        speedAccuracy: 0.5,
      );

      final validated = ValidatedLocation.fromPosition(pos);
      expect(validated, isNotNull);
      expect(validated!.latitude, 18.0674);
      expect(validated.longitude, 83.3980);
      expect(validated.accuracyMeters, 8.5);
      expect(validated.isReliable, isTrue);
      expect(validated.isFresh, isTrue);
      expect(validated.headingDegrees, 90.0);
      expect(validated.speedMps, 12.0);
    });

    test('Position with degraded accuracy (> 35m) is marked unreliable', () {
      final pos = Position(
        latitude: 18.0674,
        longitude: 83.3980,
        timestamp: DateTime.now(),
        accuracy: 65.0, // Exceeds maxAcceptableAccuracyMeters (35.0)
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final validated = ValidatedLocation.fromPosition(pos);
      expect(validated, isNotNull);
      expect(validated!.isReliable, isFalse);
    });

    test('Stale position (> 15 seconds old) is marked not fresh', () {
      final pastTime = DateTime.now().subtract(const Duration(seconds: 30));
      final pos = Position(
        latitude: 18.0674,
        longitude: 83.3980,
        timestamp: pastTime,
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final validated = ValidatedLocation.fromPosition(pos);
      expect(validated, isNotNull);
      expect(validated!.isFresh, isFalse);
    });

    test('Kinematic jump filter detects and rejects implausible teleportation', () {
      final t0 = DateTime.now();
      final prev = ValidatedLocation(
        latitude: 18.0674,
        longitude: 83.3980,
        accuracyMeters: 5.0,
        timestamp: t0,
        speedMps: 10.0,
        headingDegrees: 0.0,
      );

      // Jump 5 km away within 1 second (~5000 m/s > 45 m/s threshold)
      final t1 = t0.add(const Duration(seconds: 1));
      final anomalousPos = Position(
        latitude: 18.1120, // ~5 km jump
        longitude: 83.3980,
        timestamp: t1,
        accuracy: 8.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 10.0,
        speedAccuracy: 0.0,
      );

      final validated = ValidatedLocation.fromPosition(anomalousPos, previous: prev);
      expect(validated, isNotNull);
      expect(validated!.isReliable, isFalse,
          reason: 'Anomalous jump at 5000 m/s must be flagged as unreliable');
    });

    test('Plausible smooth movement is accepted by kinematic filter', () {
      final t0 = DateTime.now();
      final prev = ValidatedLocation(
        latitude: 18.0674,
        longitude: 83.3980,
        accuracyMeters: 5.0,
        timestamp: t0,
        speedMps: 15.0,
        headingDegrees: 45.0,
      );

      // Move ~30 meters over 2 seconds (15 m/s, plausible car/bike speed)
      final t1 = t0.add(const Duration(seconds: 2));
      // 0.00027 deg lat is ~30 meters
      final realisticPos = Position(
        latitude: 18.06767,
        longitude: 83.3980,
        timestamp: t1,
        accuracy: 6.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 45.0,
        headingAccuracy: 0.0,
        speed: 15.0,
        speedAccuracy: 0.0,
      );

      final validated = ValidatedLocation.fromPosition(realisticPos, previous: prev);
      expect(validated, isNotNull);
      expect(validated!.isReliable, isTrue);
    });

    test('Null Island (0, 0) position returns null', () {
      final pos = Position(
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final validated = ValidatedLocation.fromPosition(pos);
      expect(validated, isNull);
    });
  });
}

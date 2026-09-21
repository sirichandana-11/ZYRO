import 'package:flutter_test/flutter_test.dart';
import 'package:zyro/models/coordinate.dart';

void main() {
  group('Coordinate Validation Tests', () {
    test('Valid standard coordinates return true', () {
      expect(Coordinate.isValid(12.9716, 77.5946), isTrue); // Bengaluru
      expect(Coordinate.isValid(18.0674, 83.3980), isTrue); // Vizianagaram (Lendi)
      expect(Coordinate.isValid(-33.8688, 151.2093), isTrue); // Sydney
      expect(Coordinate.isValid(90.0, 180.0), isTrue); // Boundaries
      expect(Coordinate.isValid(-90.0, -180.0), isTrue);
    });

    test('Null, NaN, and Infinity coordinates return false', () {
      expect(Coordinate.isValid(null, 77.5946), isFalse);
      expect(Coordinate.isValid(12.9716, null), isFalse);
      expect(Coordinate.isValid(double.nan, 77.5946), isFalse);
      expect(Coordinate.isValid(12.9716, double.nan), isFalse);
      expect(Coordinate.isValid(double.infinity, 77.5946), isFalse);
      expect(Coordinate.isValid(12.9716, double.negativeInfinity), isFalse);
    });

    test('Out of bounds latitude (> 90 or < -90) returns false', () {
      expect(Coordinate.isValid(90.0001, 77.5946), isFalse);
      expect(Coordinate.isValid(-90.0001, 77.5946), isFalse);
      expect(Coordinate.isValid(120.0, 77.5946), isFalse);
    });

    test('Out of bounds longitude (> 180 or < -180) returns false', () {
      expect(Coordinate.isValid(12.9716, 180.0001), isFalse);
      expect(Coordinate.isValid(12.9716, -180.0001), isFalse);
      expect(Coordinate.isValid(12.9716, 200.0), isFalse);
    });

    test('Null Island (0.0, 0.0) is rejected by default', () {
      expect(Coordinate.isValid(0.0, 0.0), isFalse);
    });

    test('Coordinate clamping works as expected', () {
      final clamped = Coordinate.clamp(105.0, -195.0);
      expect(clamped.latitude, 90.0);
      expect(clamped.longitude, -180.0);
    });

    test('Display string formatting', () {
      const coord = Coordinate(latitude: 18.067421, longitude: 83.398012);
      expect(coord.toDisplayString(precision: 4), '18.0674, 83.3980');
    });
  });
}

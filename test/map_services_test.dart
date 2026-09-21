import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zyro/services/geocoding_service.dart';
import 'package:zyro/services/routing_service.dart';

void main() {
  group('GeocodingLocation Model', () {
    test('Correctly parses Nominatim JSON', () {
      final json = {
        'lat': '12.9716',
        'lon': '77.5946',
        'display_name': 'Bengaluru, Karnataka, India',
        'name': 'Bengaluru',
      };

      final location = GeocodingLocation.fromJson(json);
      expect(location.latitude, 12.9716);
      expect(location.longitude, 77.5946);
      expect(location.displayName, 'Bengaluru, Karnataka, India');
      expect(location.shortName, 'Bengaluru');
    });

    test('Handles missing name and trims display name', () {
      final json = {
        'lat': '12.9352',
        'lon': '77.6245',
        'display_name': 'Koramangala, Bengaluru, Karnataka',
      };

      final location = GeocodingLocation.fromJson(json);
      expect(location.latitude, 12.9352);
      expect(location.longitude, 77.6245);
      expect(location.shortName, 'Koramangala');
    });
  });

  group('RouteResult Model', () {
    test('Formatted distance and duration helper formatting', () {
      final route = RouteResult(
        points: const [
          LatLng(12.9716, 77.5946),
          LatLng(12.9352, 77.6245),
        ],
        distanceKm: 5.4,
        durationMinutes: 14.2,
      );

      expect(route.formattedDistance, '5.4 km');
      expect(route.formattedDuration, '14 mins');
    });

    test('Formatted distance for under 1km', () {
      final route = RouteResult(
        points: const [LatLng(12.9716, 77.5946)],
        distanceKm: 0.65,
        durationMinutes: 1.0,
      );

      expect(route.formattedDistance, '650 m');
      expect(route.formattedDuration, '1 min');
    });
  });
}

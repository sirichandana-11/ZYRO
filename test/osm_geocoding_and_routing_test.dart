import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zyro/models/coordinate.dart';
import 'package:zyro/services/geocoding_service.dart';
import 'package:zyro/services/routing_service.dart';

void main() {
  group('OpenStreetMap & Nominatim Geocoding Tests', () {
    test('NominatimGeocodingService provides correct attribution', () {
      final service = NominatimGeocodingService();
      expect(service.attribution, contains('OpenStreetMap'));
      expect(service.attribution, contains('Nominatim'));
    });

    test('GeocodingLocation.fromJson parses valid Nominatim JSON correctly', () {
      final json = {
        'lat': '18.1130',
        'lon': '83.4024',
        'display_name': 'Vizianagaram Railway Station, Mayur Junction, Vizianagaram, Andhra Pradesh, 535003, India',
        'name': 'Vizianagaram Railway Station',
      };

      final location = GeocodingLocation.fromJson(json);
      expect(location.latitude, 18.1130);
      expect(location.longitude, 83.4024);
      expect(location.shortName, 'Vizianagaram Railway Station');
      expect(location.displayName, contains('Vizianagaram Railway Station'));
      expect(Coordinate.isValid(location.latitude, location.longitude), isTrue);
    });

    test('GeocodingLocation rejects invalid or out-of-bound coordinates', () {
      final invalidLat = Coordinate.isValid(95.0, 83.0);
      final invalidLng = Coordinate.isValid(18.0, 185.0);
      final nullIsland = Coordinate.isValid(0.0, 0.0);
      final valid = Coordinate.isValid(18.1130, 83.4024);

      expect(invalidLat, isFalse);
      expect(invalidLng, isFalse);
      expect(nullIsland, isFalse);
      expect(valid, isTrue);
    });

    test('Nominatim reverseGeocode rejects (0,0) Null Island coordinates', () async {
      final service = NominatimGeocodingService();
      final result = await service.reverseGeocode(0.0, 0.0);
      expect(result, isNull);
    });
  });

  group('OSRM Road Routing Tests', () {
    test('OsrmRoutingService provides correct provider name', () {
      final service = OsrmRoutingService();
      expect(service.providerName, contains('OSRM'));
      expect(service.providerName, contains('Open Source Routing Machine'));
    });

    test('RouteResult correctly formats distances and durations', () {
      const shortRoute = RouteResult(
        points: [LatLng(18.0674, 83.3980), LatLng(18.0700, 83.4000)],
        distanceKm: 0.45,
        durationMinutes: 1.2,
      );
      expect(shortRoute.formattedDistance, '450 m');
      expect(shortRoute.formattedDuration, '1 min');

      const mediumRoute = RouteResult(
        points: [LatLng(18.0674, 83.3980), LatLng(18.1130, 83.4024)],
        distanceKm: 6.8,
        durationMinutes: 14.0,
      );
      expect(mediumRoute.formattedDistance, '6.8 km');
      expect(mediumRoute.formattedDuration, '14 mins');

      const longRoute = RouteResult(
        points: [LatLng(18.0674, 83.3980), LatLng(17.6868, 83.2185)],
        distanceKm: 58.4,
        durationMinutes: 75.0,
      );
      expect(longRoute.formattedDistance, '58.4 km');
      expect(longRoute.formattedDuration, '1h 15m');
    });

    test('OsrmRoutingService.getRoute rejects invalid origin or destination', () async {
      final service = OsrmRoutingService();
      final result = await service.getRoute(
        origin: const LatLng(0.0, 0.0),
        destination: const LatLng(18.1130, 83.4024),
      );
      expect(result, isNull);
    });
  });
}

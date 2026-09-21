import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Represents a geographic location returned by the geocoding service.
class GeocodingLocation {
  final double latitude;
  final double longitude;
  final String displayName;
  final String shortName;

  const GeocodingLocation({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    required this.shortName,
  });

  factory GeocodingLocation.fromJson(Map<String, dynamic> json) {
    final latitude =
        double.tryParse(json['lat']?.toString() ?? '') ?? 0.0;

    final longitude =
        double.tryParse(json['lon']?.toString() ?? '') ?? 0.0;

    final displayName =
        json['display_name']?.toString() ?? '';

    String shortName =
        displayName.split(',').first.trim();

    final jsonName = json['name']?.toString();

    if (jsonName != null && jsonName.trim().isNotEmpty) {
      shortName = jsonName.trim();
    }

    return GeocodingLocation(
      latitude: latitude,
      longitude: longitude,
      displayName: displayName,
      shortName: shortName,
    );
  }

  @override
  String toString() {
    return '$shortName ($latitude, $longitude)';
  }
}

/// Abstract geocoding service.
abstract class GeocodingService {
  Future<List<GeocodingLocation>> search(
    String query, {
    double? proximityLat,
    double? proximityLng,
  });

  Future<String?> reverseGeocode(
    double latitude,
    double longitude,
  );

  String get attribution;
}

/// Nominatim / OpenStreetMap implementation.
class NominatimGeocodingService implements GeocodingService {
  static final NominatimGeocodingService _instance =
      NominatimGeocodingService._internal();

  factory NominatimGeocodingService() => _instance;

  NominatimGeocodingService._internal();

  final Map<String, List<GeocodingLocation>> _searchCache = {};

  final Map<String, String> _reverseCache = {};

  DateTime _lastRequestTime =
      DateTime.fromMillisecondsSinceEpoch(0);

  static const Duration _minRequestInterval =
      Duration(milliseconds: 1100);

  static const String _userAgent =
      'ZYRO-RideHailingApp/1.0.0 (contact@zyro.app)';

  @override
  String get attribution =>
      '© OpenStreetMap contributors, Nominatim';

  /// Ensures requests are not sent too quickly.
  Future<void> _throttle() async {
    final now = DateTime.now();

    final elapsed =
        now.difference(_lastRequestTime);

    if (elapsed < _minRequestInterval) {
      final waitTime =
          _minRequestInterval - elapsed;

      await Future.delayed(waitTime);
    }

    _lastRequestTime = DateTime.now();
  }

  /// Creates a cache key using both the search text and
  /// the pickup/proximity location.
  ///
  /// This is important because searching "Denkada" from
  /// different pickup locations should not reuse an old
  /// result blindly.
  String _buildSearchCacheKey(
    String query,
    double? proximityLat,
    double? proximityLng,
  ) {
    return [
      query.trim().toLowerCase(),
      proximityLat?.toStringAsFixed(4) ?? '',
      proximityLng?.toStringAsFixed(4) ?? '',
    ].join('|');
  }

  /// Calculates approximate distance between two coordinates.
  double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat =
        _degreesToRadians(lat2 - lat1);

    final dLon =
        _degreesToRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) *
                math.sin(dLat / 2) +
            math.cos(
              _degreesToRadians(lat1),
            ) *
                math.cos(
                  _degreesToRadians(lat2),
                ) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final c =
        2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  @override
  Future<List<GeocodingLocation>> search(
    String query, {
    double? proximityLat,
    double? proximityLng,
  }) async {
    final cleanQuery = query.trim();

    if (cleanQuery.length < 2) {
      return [];
    }

    final cacheKey = _buildSearchCacheKey(
      cleanQuery,
      proximityLat,
      proximityLng,
    );

    final cached = _searchCache[cacheKey];

    if (cached != null) {
      return cached;
    }

    try {
      await _throttle();

      final uriParams = <String, String>{
        'q': cleanQuery,
        'format': 'jsonv2',
        'addressdetails': '1',

        // Give the user several choices.
        'limit': '8',

        // Ask Nominatim for important/relevant results.
        'dedupe': '1',
      };

      // If pickup coordinates are available, use them
      // to bias search results toward the pickup area.
      if (proximityLat != null &&
          proximityLng != null) {
        const delta = 0.5;

        uriParams['viewbox'] =
            '${proximityLng - delta},'
            '${proximityLat + delta},'
            '${proximityLng + delta},'
            '${proximityLat - delta}';

        // Keep bounded=0 so valid locations outside
        // the box are not completely removed.
        uriParams['bounded'] = '0';
      }

      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        uriParams,
      );

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
              'Accept-Language': 'en',
            },
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        debugPrint(
          'Nominatim search failed: '
          '${response.statusCode}',
        );

        return [];
      }

      final decoded =
          jsonDecode(response.body);

      if (decoded is! List) {
        return [];
      }

      final results = decoded
          .whereType<Map<String, dynamic>>()
          .map(
            GeocodingLocation.fromJson,
          )
          .where(
            (location) =>
                location.latitude != 0.0 &&
                location.longitude != 0.0 &&
                location.latitude >= -90 &&
                location.latitude <= 90 &&
                location.longitude >= -180 &&
                location.longitude <= 180,
          )
          .toList();

      // If we know the pickup location, put nearby
      // matching results first.
      if (proximityLat != null &&
          proximityLng != null) {
        results.sort((a, b) {
          final distanceA = _distanceKm(
            proximityLat,
            proximityLng,
            a.latitude,
            a.longitude,
          );

          final distanceB = _distanceKm(
            proximityLat,
            proximityLng,
            b.latitude,
            b.longitude,
          );

          return distanceA.compareTo(distanceB);
        });
      }

      // Debug information is extremely useful while
      // testing ZYRO's location selection.
      for (final result in results) {
        final distanceText =
            proximityLat != null &&
                    proximityLng != null
                ? '${_distanceKm(
                    proximityLat,
                    proximityLng,
                    result.latitude,
                    result.longitude,
                  ).toStringAsFixed(2)} km from pickup'
                : 'no proximity';

        debugPrint(
          'ZYRO LOCATION RESULT: '
          '${result.displayName} | '
          'lat=${result.latitude} | '
          'lon=${result.longitude} | '
          '$distanceText',
        );
      }

      _searchCache[cacheKey] = results;

      return results;
    } catch (e) {
      debugPrint(
        'Nominatim search error: $e',
      );

      return [];
    }
  }

  @override
  Future<String?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    if (latitude == 0.0 &&
        longitude == 0.0) {
      return null;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    final cacheKey =
        '${latitude.toStringAsFixed(5)},'
        '${longitude.toStringAsFixed(5)}';

    final cached = _reverseCache[cacheKey];

    if (cached != null) {
      return cached;
    }

    try {
      await _throttle();

      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'format': 'jsonv2',
          'addressdetails': '1',
        },
      );

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
              'Accept-Language': 'en',
            },
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        debugPrint(
          'Nominatim reverse failed: '
          '${response.statusCode}',
        );

        return null;
      }

      final decoded =
          jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final displayName =
            decoded['display_name']?.toString();

        if (displayName != null &&
            displayName.trim().isNotEmpty) {
          _reverseCache[cacheKey] =
              displayName.trim();

          return displayName.trim();
        }
      }
    } catch (e) {
      debugPrint(
        'Nominatim reverseGeocode error: $e',
      );
    }

    return null;
  }
}
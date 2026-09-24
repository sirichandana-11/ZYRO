import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/coordinate.dart';

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

/// Abstract geocoding service interface.
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

  /// Default production geocoding service backed by OpenStreetMap Nominatim.
  static GeocodingService get instance => NominatimGeocodingService();
}

/// Production Nominatim / OpenStreetMap Geocoding Implementation.
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

  /// Ensures requests adhere to Nominatim rate limits.
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
        'limit': '8',
        'dedupe': '1',
      };

      if (proximityLat != null &&
          proximityLng != null) {
        const delta = 0.5;

        uriParams['viewbox'] =
            '${proximityLng - delta},'
            '${proximityLat + delta},'
            '${proximityLng + delta},'
            '${proximityLat - delta}';

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

      final results = <GeocodingLocation>[];

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final location =
              GeocodingLocation.fromJson(item);

          // Validate coordinates: reject (0,0), NaN, out-of-bounds
          if (Coordinate.isValid(
            location.latitude,
            location.longitude,
          )) {
            results.add(location);
          }
        }
      }

      if (proximityLat != null &&
          proximityLng != null &&
          results.length > 1) {
        results.sort((a, b) {
          final distA = _distanceKm(
            proximityLat,
            proximityLng,
            a.latitude,
            a.longitude,
          );

          final distB = _distanceKm(
            proximityLat,
            proximityLng,
            b.latitude,
            b.longitude,
          );

          return distA.compareTo(distB);
        });
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
    if (!Coordinate.isValid(latitude, longitude)) {
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
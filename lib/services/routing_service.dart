import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/coordinate.dart';

/// Represents a calculated road route.
class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });

  String get formattedDistance {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()} m';
    }

    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final mins = durationMinutes.round();

    if (mins <= 1) {
      return '1 min';
    }

    if (mins < 60) {
      return '$mins mins';
    }

    final hours = mins ~/ 60;
    final remainingMinutes = mins % 60;

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }
}

/// Abstract routing service interface.
abstract class RoutingService {
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
  });

  String get providerName;

  /// Default production routing service backed by OSRM.
  static RoutingService get instance => OsrmRoutingService();
}

/// OSRM road-routing implementation.
class OsrmRoutingService implements RoutingService {
  static final OsrmRoutingService _instance =
      OsrmRoutingService._internal();

  factory OsrmRoutingService() => _instance;

  OsrmRoutingService._internal();

  final Map<String, RouteResult> _cache = {};

  static const String _userAgent =
      'ZYRO-RideHailingApp/1.0.0 (contact@zyro.app)';

  @override
  String get providerName =>
      'OSRM (Open Source Routing Machine)';

  String _buildCacheKey(
    LatLng origin,
    LatLng destination,
  ) {
    return '${origin.latitude.toStringAsFixed(5)},'
        '${origin.longitude.toStringAsFixed(5)}'
        '->'
        '${destination.latitude.toStringAsFixed(5)},'
        '${destination.longitude.toStringAsFixed(5)}';
  }

  bool _isValidCoordinate(LatLng point) {
    return Coordinate.isValid(
      point.latitude,
      point.longitude,
    );
  }

  @override
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (!_isValidCoordinate(origin) ||
        !_isValidCoordinate(destination)) {
      return null;
    }

    final cacheKey =
        _buildCacheKey(origin, destination);

    final cached = _cache[cacheKey];

    if (cached != null) {
      return cached;
    }

    final coordinates =
        '${origin.longitude.toStringAsFixed(6)},'
        '${origin.latitude.toStringAsFixed(6)};'
        '${destination.longitude.toStringAsFixed(6)},'
        '${destination.latitude.toStringAsFixed(6)}';

    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$coordinates',
      {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
            },
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded =
          jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final code = decoded['code']?.toString();

      if (code != 'Ok') {
        return null;
      }

      final routes = decoded['routes'];

      if (routes is! List || routes.isEmpty) {
        return null;
      }

      final primary =
          routes.first as Map<String, dynamic>;

      final distanceMeters =
          (primary['distance'] as num?)
                  ?.toDouble() ??
              0.0;

      final durationSeconds =
          (primary['duration'] as num?)
                  ?.toDouble() ??
              0.0;

      final geometry =
          primary['geometry'] as Map<String, dynamic>?;

      final rawCoordinates =
          geometry?['coordinates'] as List<dynamic>?;

      final points = <LatLng>[];

      if (rawCoordinates != null) {
        for (final pair in rawCoordinates) {
          if (pair is List && pair.length >= 2) {
            final lon =
                (pair[0] as num).toDouble();

            final lat =
                (pair[1] as num).toDouble();

            if (Coordinate.isValid(lat, lon)) {
              points.add(LatLng(lat, lon));
            }
          }
        }
      }

      if (points.isEmpty) {
        points.add(origin);
        points.add(destination);
      }

      final result = RouteResult(
        points: points,
        distanceKm: distanceMeters / 1000.0,
        durationMinutes: durationSeconds / 60.0,
      );

      _cache[cacheKey] = result;

      return result;
    } catch (e) {
      debugPrint('OSRM routing error: $e');
      return null;
    }
  }
}
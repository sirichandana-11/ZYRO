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

/// Abstract routing service.
abstract class RoutingService {
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
  });

  String get providerName;
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
    // Validate origin.
    if (!_isValidCoordinate(origin)) {
      debugPrint(
        'ZYRO routing: invalid origin '
        '${origin.latitude}, ${origin.longitude}',
      );

      return null;
    }

    // Validate destination.
    if (!_isValidCoordinate(destination)) {
      debugPrint(
        'ZYRO routing: invalid destination '
        '${destination.latitude}, ${destination.longitude}',
      );

      return null;
    }

    // Same location.
    if (origin.latitude == destination.latitude &&
        origin.longitude == destination.longitude) {
      return RouteResult(
        points: [origin],
        distanceKm: 0.0,
        durationMinutes: 0.0,
      );
    }

    final cacheKey =
        _buildCacheKey(origin, destination);

    final cached = _cache[cacheKey];

    if (cached != null) {
      return cached;
    }

    try {
      /*
       * IMPORTANT:
       *
       * OSRM requires:
       * longitude,latitude
       *
       * NOT:
       * latitude,longitude
       */
      final coordinates =
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}';

      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/$coordinates',
        {
          // Complete road geometry.
          'overview': 'full',

          // GeoJSON makes decoding easy.
          'geometries': 'geojson',

          // We need one normal route.
          'alternatives': 'false',

          // Allow the routing engine to choose
          // the appropriate continuation.
          'continue_straight': 'false',
        },
      );

      debugPrint(
        'ZYRO ROUTE REQUEST:\n'
        'Origin: ${origin.latitude}, ${origin.longitude}\n'
        'Destination: ${destination.latitude}, '
        '${destination.longitude}',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) {
        debugPrint(
          'OSRM routing HTTP error: '
          '${response.statusCode}',
        );

        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        debugPrint(
          'OSRM returned unexpected response.',
        );

        return null;
      }

      final responseCode =
          decoded['code']?.toString();

      if (responseCode != 'Ok') {
        debugPrint(
          'OSRM route error: $responseCode',
        );

        return null;
      }

      final routes = decoded['routes'];

      if (routes is! List ||
          routes.isEmpty) {
        debugPrint(
          'OSRM returned no routes.',
        );

        return null;
      }

      final firstRoute =
          routes.first;

      if (firstRoute
          is! Map<String, dynamic>) {
        return null;
      }

      final distanceMeters =
          (firstRoute['distance'] as num?)
                  ?.toDouble() ??
              0.0;

      final durationSeconds =
          (firstRoute['duration'] as num?)
                  ?.toDouble() ??
              0.0;

      if (distanceMeters <= 0) {
        debugPrint(
          'OSRM returned zero route distance.',
        );

        return null;
      }

      final geometry =
          firstRoute['geometry'];

      if (geometry
          is! Map<String, dynamic>) {
        debugPrint(
          'OSRM route has no geometry.',
        );

        return null;
      }

      final coordinatesList =
          geometry['coordinates'];

      if (coordinatesList is! List ||
          coordinatesList.isEmpty) {
        debugPrint(
          'OSRM route geometry is empty.',
        );

        return null;
      }

      final routePoints = <LatLng>[];

      for (final item in coordinatesList) {
        if (item is! List ||
            item.length < 2) {
          continue;
        }

        final longitude =
            (item[0] as num?)?.toDouble();

        final latitude =
            (item[1] as num?)?.toDouble();

        if (latitude == null ||
            longitude == null) {
          continue;
        }

        if (latitude < -90 ||
            latitude > 90 ||
            longitude < -180 ||
            longitude > 180) {
          continue;
        }

        routePoints.add(
          LatLng(
            latitude,
            longitude,
          ),
        );
      }

      if (routePoints.length < 2) {
        debugPrint(
          'OSRM returned insufficient route points.',
        );

        return null;
      }

      final result = RouteResult(
        points: routePoints,
        distanceKm:
            distanceMeters / 1000.0,
        durationMinutes:
            durationSeconds / 60.0,
      );

      _cache[cacheKey] = result;

      debugPrint(
        'ZYRO ROUTE RESULT: '
        '${result.formattedDistance} | '
        '${result.formattedDuration} | '
        'points=${routePoints.length}',
      );

      return result;
    } catch (e) {
      debugPrint(
        'ZYRO routing error: $e',
      );

      return null;
    }
  }
}
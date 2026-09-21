import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/coordinate.dart';
import '../models/validated_location.dart';

enum LocationServiceStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  error,
  stale,
}

enum LocationPermissionState {
  grantedPrecise,
  grantedCoarse,
  denied,
  deniedForever,
  undetermined,
}

enum LocationServiceState {
  enabled,
  disabled,
}

enum LocationAvailabilityState {
  acquiring,
  available,
  stale,
  unavailable,
  permissionRequired,
  servicesDisabled,
}

class LocationResult {
  final LocationServiceStatus status;
  final ValidatedLocation? validatedLocation;
  final Position? rawPosition;
  final String? message;
  final LocationPermissionState permissionState;
  final LocationServiceState serviceState;

  const LocationResult({
    required this.status,
    this.validatedLocation,
    this.rawPosition,
    this.message,
    this.permissionState = LocationPermissionState.undetermined,
    this.serviceState = LocationServiceState.disabled,
  });

  bool get isSuccess =>
      status == LocationServiceStatus.ready && validatedLocation != null;
  Position? get position => rawPosition;
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal() {
    _initSharedStream();
  }

  ValidatedLocation? _lastValidatedLocation;
  Position? _lastRawPosition;
  int _totalUpdatesReceived = 0;
  int _rejectedJumpsCount = 0;

  ValidatedLocation? get lastValidatedLocation => _lastValidatedLocation;
  Position? get lastRawPosition => _lastRawPosition;
  int get totalUpdatesReceived => _totalUpdatesReceived;
  int get rejectedJumpsCount => _rejectedJumpsCount;

  final StreamController<ValidatedLocation> _locationStreamController =
      StreamController<ValidatedLocation>.broadcast();

  StreamSubscription<Position>? _geolocatorSubscription;

  /// Centralized, battery-optimized validated location stream for all app components.
  Stream<ValidatedLocation> get validatedLocationStream =>
      _locationStreamController.stream;

  void _initSharedStream() {
    // Lazy initialized on first listener if needed
  }

  /// Check GPS service and permissions, and retrieve current validated position
  Future<LocationResult> determinePosition({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 12),
  }) async {
    try {
      // 1. Check if location services are enabled on device
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          status: LocationServiceStatus.serviceDisabled,
          serviceState: LocationServiceState.disabled,
          permissionState: LocationPermissionState.undetermined,
          message:
              'Device location services are turned off. Please enable GPS in device settings.',
        );
      }

      // 2. Check current location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            status: LocationServiceStatus.permissionDenied,
            serviceState: LocationServiceState.enabled,
            permissionState: LocationPermissionState.denied,
            message:
                'Location permission was denied. ZYRO needs location access to find nearby rides.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          status: LocationServiceStatus.permissionPermanentlyDenied,
          serviceState: LocationServiceState.enabled,
          permissionState: LocationPermissionState.deniedForever,
          message:
              'Location permissions are permanently denied. Please enable them in device settings.',
        );
      }

      final LocationPermissionState permState =
          (permission == LocationPermission.always ||
                  permission == LocationPermission.whileInUse)
              ? LocationPermissionState.grantedPrecise
              : LocationPermissionState.grantedCoarse;

      // 3. Permissions granted - fetch current position with timeout
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: desiredAccuracy,
          timeLimit: timeLimit,
        ),
      );

      _lastRawPosition = position;
      _totalUpdatesReceived++;

      final validated = ValidatedLocation.fromPosition(
        position,
        previous: _lastValidatedLocation,
      );

      if (validated == null || !validated.isReliable) {
        // If kinematic jump was rejected
        if (validated != null && !validated.isReliable) {
          _rejectedJumpsCount++;
        }
        // If coordinate is still numerically valid, use with caution
        if (Coordinate.isValid(position.latitude, position.longitude)) {
          final fallbackValidated = ValidatedLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            timestamp: position.timestamp,
            speedMps: position.speed >= 0 ? position.speed : 0.0,
            headingDegrees: position.heading >= 0 ? position.heading : 0.0,
            isFresh: true,
            isReliable: true,
            isMocked: position.isMocked,
          );
          _lastValidatedLocation = fallbackValidated;
          _ensureLiveStreamRunning();
          return LocationResult(
            status: LocationServiceStatus.ready,
            validatedLocation: fallbackValidated,
            rawPosition: position,
            permissionState: permState,
            serviceState: LocationServiceState.enabled,
          );
        }

        return LocationResult(
          status: LocationServiceStatus.error,
          message: 'Received invalid GPS telemetry.',
          permissionState: permState,
          serviceState: LocationServiceState.enabled,
        );
      }

      _lastValidatedLocation = validated;
      _ensureLiveStreamRunning();

      debugPrint(
        '[LocationService] DETERMINED REAL GPS:\n'
        'Lat: ${validated.latitude}, Lng: ${validated.longitude}\n'
        'Accuracy: ±${validated.accuracyMeters.toStringAsFixed(1)}m | Heading: ${validated.headingDegrees.toStringAsFixed(0)}°\n'
        'Fresh: ${validated.isFresh} | Mocked: ${validated.isMocked}',
      );

      return LocationResult(
        status: LocationServiceStatus.ready,
        validatedLocation: validated,
        rawPosition: position,
        permissionState: permState,
        serviceState: LocationServiceState.enabled,
      );
    } catch (e) {
      debugPrint('[LocationService] Determination error: $e');
      return LocationResult(
        status: LocationServiceStatus.error,
        message: 'Could not fetch device location: ${e.toString()}',
      );
    }
  }

  void _ensureLiveStreamRunning() {
    if (_geolocatorSubscription != null) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5m filter for responsive tracking without excessive ticks
    );

    _geolocatorSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _lastRawPosition = position;
        _totalUpdatesReceived++;

        final validated = ValidatedLocation.fromPosition(
          position,
          previous: _lastValidatedLocation,
        );

        if (validated != null && validated.isReliable) {
          _lastValidatedLocation = validated;
          _locationStreamController.add(validated);
        } else if (validated != null && !validated.isReliable) {
          _rejectedJumpsCount++;
          debugPrint(
            '[LocationService] Filtered anomalous jump or inaccurate sample (±${position.accuracy.toStringAsFixed(1)}m)',
          );
        }
      },
      onError: (e) {
        debugPrint('[LocationService] Stream error: $e');
      },
    );
  }

  /// Subscribe to live location updates
  Stream<Position> getLivePositionStream({int distanceFilterMeters = 10}) {
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Open device app settings (for permanently denied permissions)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open device location settings (to turn on GPS switch)
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Check current permission state without prompting
  Future<LocationPermissionState> checkPermissionState() async {
    final perm = await Geolocator.checkPermission();
    switch (perm) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionState.grantedPrecise;
      case LocationPermission.denied:
        return LocationPermissionState.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionState.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionState.undetermined;
    }
  }

  /// Check if location service switch is enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import '../models/validated_location.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import '../services/location_service.dart';
import '../services/ride_service.dart';
import '../services/routing_service.dart';
import '../services/websocket_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/zyro_button.dart';
import '../widgets/zyro_map.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final AuthService _authService = AuthService();
  final DriverService _driverService = DriverService();
  final LocationService _locationService = LocationService();
  final RideService _rideService = RideService();
  final RoutingService _routingService = RoutingService.instance;
  final WebSocketService _webSocketService = WebSocketService.instance;

  late String _authenticatedDriverId;
  bool _isRoleChecking = true;
  bool _isAuthorizedDriver = false;

  bool _isOnline = false;
  bool _isLoadingGps = false;
  bool _isSeedingDemo = false;

  double? _currentLat;
  double? _currentLng;
  double? _accuracyMeters;
  double? _headingDegrees;
  double? _speedMps;
  DateTime? _lastGpsUpdate;
  DateTime? _lastWsBroadcastTime;
  DateTime? _lastFirestoreUpdateTime;
  LatLng? _lastWsBroadcastLocation;
  LatLng? _lastFirestoreLocation;
  String _gpsStatusMessage = 'GPS Ready';

  StreamSubscription<ValidatedLocation>? _locationSubscription;
  StreamSubscription<DriverModel?>? _driverSubscription;
  StreamSubscription<List<RideModel>>? _rideRequestsSubscription;
  StreamSubscription<RideModel?>? _activeRideSubscription;
  StreamSubscription<Map<String, dynamic>>? _wsRideCancelledSubscription;
  Timer? _tickerTimer;

  DriverModel? _currentDriver;
  RideModel? _activeRide;
  List<LatLng>? _activeRideRoutePoints;
  String? _trackedActiveRideId;

  List<RideModel> _incomingRequests = [];
  final Set<String> _acceptingRideIds = {};
  final Set<String> _declinedRideIds = {};

  @override
  void initState() {
    super.initState();
    final user = _authService.currentUser;
    _authenticatedDriverId = user?.uid ?? '';
    _verifyDriverRoleAndInitialize();
  }

  Future<void> _verifyDriverRoleAndInitialize() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isRoleChecking = false;
          _isAuthorizedDriver = false;
        });
      }
      return;
    }

    final role = await _authService.getUserRole(user.uid);
    if (!mounted) return;

    if (role != 'driver') {
      setState(() {
        _isRoleChecking = false;
        _isAuthorizedDriver = false;
      });
      return;
    }

    setState(() {
      _isRoleChecking = false;
      _isAuthorizedDriver = true;
    });

    _wsRideCancelledSubscription = _webSocketService.onRideCancelled.listen((event) {
      if (!mounted) return;
      final rideId = event['rideId'] as String?;
      if (rideId != null) {
        setState(() {
          _incomingRequests.removeWhere((r) => r.id == rideId);
          if (_activeRide?.id == rideId) {
            _activeRide = null;
            _activeRideRoutePoints = null;
          }
        });
      }
    });

    _subscribeToDriver();
    _fetchInitialPosition();
  }

  void _subscribeToDriver() {
    if (_authenticatedDriverId.isEmpty) return;

    _driverSubscription?.cancel();
    _driverSubscription =
        _driverService.watchDriver(_authenticatedDriverId).listen((driver) {
      if (mounted) {
        setState(() {
          _currentDriver = driver;
          if (driver != null) {
            _isOnline = driver.isOnline;
          }
        });
        _manageRideRequestsSubscription();
        _manageActiveRideSubscription(driver?.activeRideId);
      }
    });
  }

  void _manageActiveRideSubscription(String? activeRideId) {
    if (activeRideId == null || activeRideId.isEmpty) {
      _activeRideSubscription?.cancel();
      _activeRideSubscription = null;
      _trackedActiveRideId = null;
      if (_activeRide != null) {
        setState(() {
          _activeRide = null;
          _activeRideRoutePoints = null;
        });
      }
      return;
    }

    if (_trackedActiveRideId != activeRideId) {
      _trackedActiveRideId = activeRideId;
      _activeRideSubscription?.cancel();
      _activeRideSubscription =
          _rideService.watchRide(activeRideId).listen((ride) async {
        if (mounted) {
          setState(() {
            _activeRide = ride;
          });

          if (ride != null &&
              ride.pickupLatitude != 0.0 &&
              ride.destinationLatitude != 0.0) {
            final route = await _routingService.getRoute(
              origin: LatLng(ride.pickupLatitude, ride.pickupLongitude),
              destination:
                  LatLng(ride.destinationLatitude, ride.destinationLongitude),
            );
            if (mounted) {
              setState(() {
                _activeRideRoutePoints = route?.points;
              });
            }
          }
        }
      });
    }
  }

  void _manageRideRequestsSubscription() {
    final isAvailable = _currentDriver?.isAvailable ?? false;
    final shouldListen = _isOnline && isAvailable;

    if (!shouldListen) {
      _rideRequestsSubscription?.cancel();
      _rideRequestsSubscription = null;
      _tickerTimer?.cancel();
      _tickerTimer = null;
      if (_incomingRequests.isNotEmpty && mounted) {
        setState(() {
          _incomingRequests = [];
        });
      }
      return;
    }

    if (_rideRequestsSubscription == null) {
      _rideRequestsSubscription = _rideService
          .watchRideRequestsForDriver(_authenticatedDriverId)
          .listen((requests) {
        if (mounted) {
          setState(() {
            _incomingRequests = requests
                .where((r) => !_declinedRideIds.contains(r.id))
                .toList();
          });
          _startTickerIfNeeded();
        }
      }, onError: (e) {
        debugPrint('Error watching driver ride requests: $e');
      });
      _startTickerIfNeeded();
    }
  }

  void _startTickerIfNeeded() {
    if (_tickerTimer == null || !_tickerTimer!.isActive) {
      _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _incomingRequests.removeWhere((r) =>
                r.expiresAt != null && DateTime.now().isAfter(r.expiresAt!));
          });
        }
      });
    }
  }

  Future<void> _fetchInitialPosition() async {
    final result = await _locationService.determinePosition();
    if (result.isSuccess && result.validatedLocation != null) {
      final loc = result.validatedLocation!;
      if (mounted) {
        setState(() {
          _currentLat = loc.latitude;
          _currentLng = loc.longitude;
          _accuracyMeters = loc.accuracyMeters;
          _headingDegrees = loc.headingDegrees;
          _speedMps = loc.speedMps;
          _lastGpsUpdate = loc.timestamp;
          _gpsStatusMessage = 'Real GPS Connected';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _currentLat = null;
          _currentLng = null;
          _gpsStatusMessage = result.message ?? 'GPS Unavailable (Turn on GPS)';
        });
      }
    }
  }

  Future<void> _toggleOnline(bool value) async {
    if (value) {
      // Going ONLINE: Fetch real GPS and start live stream
      setState(() {
        _isLoadingGps = true;
      });

      final locResult = await _locationService.determinePosition();

      if (!locResult.isSuccess || locResult.validatedLocation == null) {
        setState(() {
          _isLoadingGps = false;
          _gpsStatusMessage = locResult.message ?? 'Failed to get GPS location';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: ZyroTheme.errorRed,
              content: Text(
                locResult.message ?? 'Please grant location permission to go online.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
            ),
          );
        }
        return;
      }

      final loc = locResult.validatedLocation!;
      final user = _authService.currentUser;

      final driverModel = DriverModel(
        id: _authenticatedDriverId,
        name: _currentDriver?.name.isNotEmpty == true
            ? _currentDriver!.name
            : (user?.displayName ?? 'ZYRO Driver'),
        phone: _currentDriver?.phone.isNotEmpty == true
            ? _currentDriver!.phone
            : '+91 98765 00000',
        vehicleType: _currentDriver?.vehicleType.isNotEmpty == true
            ? _currentDriver!.vehicleType
            : 'bike',
        vehicleNumber: _currentDriver?.vehicleNumber.isNotEmpty == true
            ? _currentDriver!.vehicleNumber
            : 'ZYRO-${_authenticatedDriverId.substring(0, 4).toUpperCase()}',
        isOnline: true,
        isAvailable: true,
        latitude: loc.latitude,
        longitude: loc.longitude,
        lastRideCompletedAt: _currentDriver?.lastRideCompletedAt ??
            DateTime.now().subtract(const Duration(minutes: 10)),
      );

      // Write driver record to Firestore
      await _driverService.createOrUpdateDriver(driverModel);

      // Connect to WebSocket and broadcast driver online
      _webSocketService.connect();
      _webSocketService.sendDriverOnline(
        driverId: _authenticatedDriverId,
        latitude: loc.latitude,
        longitude: loc.longitude,
      );

      _lastWsBroadcastTime = DateTime.now();
      _lastWsBroadcastLocation = LatLng(loc.latitude, loc.longitude);
      _lastFirestoreUpdateTime = DateTime.now();
      _lastFirestoreLocation = LatLng(loc.latitude, loc.longitude);

      // Start live GPS stream with smart throttling
      _locationSubscription?.cancel();
      _locationSubscription = _locationService.validatedLocationStream.listen(
        (liveLoc) {
          final now = DateTime.now();
          final currentPoint = LatLng(liveLoc.latitude, liveLoc.longitude);

          // 1. Throttled WebSocket broadcast (~2.5s or > 10m displacement)
          final bool shouldSendWs = _lastWsBroadcastTime == null ||
              now.difference(_lastWsBroadcastTime!).inMilliseconds >= 2500 ||
              (_lastWsBroadcastLocation != null &&
                  ValidatedLocation.distanceMeters(
                        _lastWsBroadcastLocation!.latitude,
                        _lastWsBroadcastLocation!.longitude,
                        liveLoc.latitude,
                        liveLoc.longitude,
                      ) >
                      10.0);

          if (shouldSendWs) {
            _lastWsBroadcastTime = now;
            _lastWsBroadcastLocation = currentPoint;
            _webSocketService.sendDriverLocation(
              latitude: liveLoc.latitude,
              longitude: liveLoc.longitude,
              speed: liveLoc.speedMps,
              heading: liveLoc.headingDegrees,
              accuracy: liveLoc.accuracyMeters,
              activeRideId: _activeRide?.id,
            );
          }

          // 2. Throttled Firestore update (~6s or > 25m displacement)
          final bool shouldUpdateFirestore = _lastFirestoreUpdateTime == null ||
              now.difference(_lastFirestoreUpdateTime!).inSeconds >= 6 ||
              (_lastFirestoreLocation != null &&
                  ValidatedLocation.distanceMeters(
                        _lastFirestoreLocation!.latitude,
                        _lastFirestoreLocation!.longitude,
                        liveLoc.latitude,
                        liveLoc.longitude,
                      ) >
                      25.0);

          if (shouldUpdateFirestore) {
            _lastFirestoreUpdateTime = now;
            _lastFirestoreLocation = currentPoint;
            _driverService.updateDriverLocation(
              driverId: _authenticatedDriverId,
              latitude: liveLoc.latitude,
              longitude: liveLoc.longitude,
            );
          }

          if (mounted) {
            setState(() {
              _currentLat = liveLoc.latitude;
              _currentLng = liveLoc.longitude;
              _accuracyMeters = liveLoc.accuracyMeters;
              _headingDegrees = liveLoc.headingDegrees;
              _speedMps = liveLoc.speedMps;
              _lastGpsUpdate = now;
            });
          }
        },
      );

      setState(() {
        _isOnline = true;
        _isLoadingGps = false;
        _currentLat = loc.latitude;
        _currentLng = loc.longitude;
        _accuracyMeters = loc.accuracyMeters;
        _headingDegrees = loc.headingDegrees;
        _speedMps = loc.speedMps;
        _lastGpsUpdate = DateTime.now();
        _gpsStatusMessage = 'Real GPS Streaming (Throttled WS + Cloud)';
      });

      _manageRideRequestsSubscription();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZyroTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'Driver is now ONLINE in Firestore & WebSocket!',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    } else {
      // Going OFFLINE: Stop GPS stream, notify WebSocket, and update Firestore
      _locationSubscription?.cancel();
      _locationSubscription = null;

      _webSocketService.sendDriverOffline(
        driverId: _authenticatedDriverId,
      );

      await _driverService.setDriverOnline(
        driverId: _authenticatedDriverId,
        isOnline: false,
      );

      setState(() {
        _isOnline = false;
        _gpsStatusMessage = 'GPS Stream Paused (Offline)';
      });

      _manageRideRequestsSubscription();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZyroTheme.darkCharcoal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'Driver is now OFFLINE',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _acceptRide(RideModel ride) async {
    if (_acceptingRideIds.contains(ride.id)) return;

    setState(() {
      _acceptingRideIds.add(ride.id);
    });

    try {
      final res = await _rideService.acceptRideTransaction(
        rideId: ride.id,
        driverId: _authenticatedDriverId,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        _webSocketService.sendRideAssigned(
          rideId: ride.id,
          driverId: _authenticatedDriverId,
          driverName: _currentDriver?.name ?? 'ZYRO Driver',
          vehicleNumber: _currentDriver?.vehicleNumber ?? 'ZYRO-101',
          vehicleType: _currentDriver?.vehicleType ?? 'bike',
          latitude: _currentLat ?? 0.0,
          longitude: _currentLng ?? 0.0,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZyroTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ride accepted! Trip assigned to you.',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZyroTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res['message'] ?? 'Ride already accepted by another driver.',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZyroTheme.errorRed,
            content: Text('Error accepting ride: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _acceptingRideIds.remove(ride.id);
        });
      }
    }
  }

  void _declineRide(RideModel ride) {
    setState(() {
      _declinedRideIds.add(ride.id);
      _incomingRequests.removeWhere((r) => r.id == ride.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZyroTheme.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          'Ride declined. 120s timer continues for other eligible drivers.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Driver Sign Out',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ZyroTheme.darkCharcoal,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of your Driver Account?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: ZyroTheme.bodyText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ZyroTheme.errorRed,
            ),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      if (_isOnline) {
        await _toggleOnline(false);
      }
      await _authService.signOut();
    }
  }

  Future<void> _seedDemoDriversInFirestore() async {
    if (_currentLat == null || _currentLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZyroTheme.errorRed,
          content: Text(
            'Please enable GPS to acquire current location before seeding pool.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSeedingDemo = true;
    });

    try {
      await _driverService.initializeDemoDrivers(
        centerLat: _currentLat!,
        centerLng: _currentLng!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZyroTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              '5 Demo candidate drivers initialized around current GPS for matching pool!',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZyroTheme.errorRed,
            content: Text('Failed to seed demo drivers: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSeedingDemo = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_isOnline && _authenticatedDriverId.isNotEmpty) {
      _webSocketService.sendDriverOffline(driverId: _authenticatedDriverId);
    }
    _locationSubscription?.cancel();
    _driverSubscription?.cancel();
    _rideRequestsSubscription?.cancel();
    _activeRideSubscription?.cancel();
    _wsRideCancelledSubscription?.cancel();
    _tickerTimer?.cancel();
    super.dispose();
  }

  IconData _getVehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler_rounded;
      case 'auto':
        return Icons.electric_rickshaw_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRoleChecking) {
      return Scaffold(
        backgroundColor: ZyroTheme.scaffoldBg(context),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ZyroTheme.primaryColor),
          ),
        ),
      );
    }

    if (!_isAuthorizedDriver) {
      return Scaffold(
        backgroundColor: ZyroTheme.scaffoldBg(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ZyroTheme.errorRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: ZyroTheme.errorRed,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Driver Account Required',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ZyroTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your authenticated account has Rider permissions. To access the Driver Dashboard, please log out and sign in with a registered Driver account.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    color: ZyroTheme.textSecondary(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ZyroButton(
                  text: 'Log Out & Switch Account',
                  icon: Icons.logout_rounded,
                  onPressed: () async {
                    await _authService.signOut();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = _authService.currentUser;
    final displayName = _currentDriver?.name.isNotEmpty == true
        ? _currentDriver!.name
        : (user?.displayName ?? 'ZYRO Driver');
    final displayVehicleType = _currentDriver?.vehicleType.isNotEmpty == true
        ? _currentDriver!.vehicleType
        : 'bike';
    final displayVehicleNumber = _currentDriver?.vehicleNumber.isNotEmpty == true
        ? _currentDriver!.vehicleNumber
        : 'ZYRO-${_authenticatedDriverId.substring(0, 4).toUpperCase()}';
    final isAvailable = _currentDriver?.isAvailable ?? false;
    final activeRideId = _currentDriver?.activeRideId;

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: ZyroTheme.cardBg(context),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver Dashboard',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ZyroTheme.textPrimary(context),
              ),
            ),
            Text(
              'UID: ${_authenticatedDriverId.substring(0, 8)}... • ${displayVehicleType.toUpperCase()}',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: ZyroTheme.mutedText,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: ZyroTheme.errorRed),
            tooltip: 'Sign Out Driver',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Online / Offline Status Card
              _buildOnlineStatusCard(
                displayName: displayName,
                vehicleType: displayVehicleType,
                vehicleNumber: displayVehicleNumber,
                isAvailable: isAvailable,
              ),
              const SizedBox(height: 16),

              // Live OpenStreetMap for Driver
              ZyroMap(
                height: 230,
                driverLocation: _currentLat != null && _currentLng != null
                    ? LatLng(_currentLat!, _currentLng!)
                    : null,
                driverName: displayName,
                driverHeading: _headingDegrees,
                driverSpeed: _speedMps,
                driverLastUpdated: _lastGpsUpdate,
                isDriverMode: true,
                autoTrackGps: false,
                pickupLocation: _activeRide != null && _activeRide!.pickupLatitude != 0.0
                    ? LatLng(_activeRide!.pickupLatitude, _activeRide!.pickupLongitude)
                    : null,
                destinationLocation: _activeRide != null && _activeRide!.destinationLatitude != 0.0
                    ? LatLng(_activeRide!.destinationLatitude, _activeRide!.destinationLongitude)
                    : null,
                routePoints: _activeRideRoutePoints,
              ),
              const SizedBox(height: 16),

              // Live Real GPS Telemetry Card
              _buildGpsTelemetryCard(),
              const SizedBox(height: 16),

              // Live Real Driver Earnings & Stats Card
              _buildDriverEarningsCard(),
              const SizedBox(height: 16),

              // Active Ride / Incoming Dispatch Status Card
              _buildDispatchStatusCard(
                isAvailable: isAvailable,
                activeRideId: activeRideId,
              ),
              const SizedBox(height: 20),

              // Candidate Pool Seeder (DEV ONLY for presentation allocation testing)
              _buildDemoSeedCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineStatusCard({
    required String displayName,
    required String vehicleType,
    required String vehicleNumber,
    required bool isAvailable,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ZyroTheme.softCardShadow,
        border: Border.all(
          color: _isOnline ? const Color(0xFF86EFAC) : ZyroTheme.borderLight,
          width: _isOnline ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _isOnline
                    ? const Color(0xFFDCFCE7)
                    : ZyroTheme.primarySurface,
                child: Icon(
                  _getVehicleIcon(vehicleType),
                  color: _isOnline ? const Color(0xFF16A34A) : ZyroTheme.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: ZyroTheme.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$vehicleNumber • ${vehicleType.toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ZyroTheme.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingGps)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                Switch.adaptive(
                  value: _isOnline,
                  activeTrackColor: const Color(0xFF16A34A),
                  onChanged: (val) => _toggleOnline(val),
                ),
            ],
          ),
          const Divider(height: 28, color: ZyroTheme.borderLight),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnline
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOnline ? 'ONLINE & READY' : 'OFFLINE',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                      color: _isOnline
                          ? const Color(0xFF166534)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isAvailable ? 'AVAILABLE' : 'BUSY / ON RIDE',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: isAvailable
                        ? const Color(0xFF15803D)
                        : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGpsTelemetryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ZyroTheme.softCardShadow,
        border: Border.all(color: ZyroTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.satellite_alt_rounded,
                  size: 18, color: ZyroTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Live Device GPS Telemetry',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: ZyroTheme.darkCharcoal,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Firestore Sync',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ZyroTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ZyroTheme.isDarkMode(context)
                        ? ZyroTheme.surfaceDarkElevated
                        : ZyroTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZyroTheme.borderColor(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LATITUDE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ZyroTheme.mutedText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentLat != null
                            ? _currentLat!.toStringAsFixed(6)
                            : 'Fetching...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: ZyroTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ZyroTheme.isDarkMode(context)
                        ? ZyroTheme.surfaceDarkElevated
                        : ZyroTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZyroTheme.borderColor(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LONGITUDE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ZyroTheme.mutedText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentLng != null
                            ? _currentLng!.toStringAsFixed(6)
                            : 'Fetching...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: ZyroTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _isOnline
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 14,
                color: _isOnline ? const Color(0xFF16A34A) : ZyroTheme.mutedText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _lastGpsUpdate != null
                      ? '$_gpsStatusMessage • ${_lastGpsUpdate!.hour.toString().padLeft(2, '0')}:${_lastGpsUpdate!.minute.toString().padLeft(2, '0')}:${_lastGpsUpdate!.second.toString().padLeft(2, '0')}'
                      : _gpsStatusMessage,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _isOnline
                        ? const Color(0xFF166534)
                        : ZyroTheme.mutedText,
                  ),
                ),
              ),
              if (_accuracyMeters != null)
                Text(
                  '±${_accuracyMeters!.toStringAsFixed(0)}m accuracy',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: ZyroTheme.mutedText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchStatusCard({
    required bool isAvailable,
    String? activeRideId,
  }) {
    final hasActiveRide = activeRideId != null && activeRideId.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ZyroTheme.softCardShadow,
        border: Border.all(color: ZyroTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 20, color: ZyroTheme.accentYellow),
              const SizedBox(width: 8),
              Text(
                _isOnline && isAvailable
                    ? 'Ride Requests (${_incomingRequests.length})'
                    : 'Ride Dispatch & Allocation Status',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: ZyroTheme.darkCharcoal,
                ),
              ),
              const Spacer(),
              if (_isOnline && isAvailable && _incomingRequests.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'LIVE OFFERS',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isOnline) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZyroTheme.isDarkMode(context)
                    ? ZyroTheme.surfaceDarkElevated
                    : ZyroTheme.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ZyroTheme.borderColor(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.power_settings_new_rounded,
                      size: 20, color: ZyroTheme.mutedText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Turn Online to receive ride offers from nearby riders in real time.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: ZyroTheme.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (hasActiveRide || !isAvailable) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car_filled_rounded,
                          size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(
                        'ACTIVE RIDE IN PROGRESS',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ride ID: ${activeRideId ?? "Assigned"}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ZyroTheme.darkCharcoal,
                    ),
                  ),
                  if (_activeRide != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Fare: ₹${_activeRide!.fare.toStringAsFixed(0)} • Status: ${_activeRide!.status.toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ZyroTheme.primaryColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_activeRide?.status == RideStatus.driverAssigned ||
                          _activeRide?.status == RideStatus.driverArriving) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (activeRideId != null) {
                                await _rideService.updateRideStatus(
                                  rideId: activeRideId,
                                  status: RideStatus.driverArrived,
                                );
                              }
                            },
                            icon: const Icon(Icons.pin_drop_rounded, size: 16),
                            label: const Text('Arrived at Pickup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ZyroTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ] else if (_activeRide?.status ==
                          RideStatus.driverArrived) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (activeRideId != null) {
                                await _rideService.updateRideStatus(
                                  rideId: activeRideId,
                                  status: RideStatus.rideStarted,
                                );
                              }
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            label: const Text('Start Trip'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (activeRideId != null) {
                                await _rideService.updateRideStatus(
                                  rideId: activeRideId,
                                  status: RideStatus.completed,
                                );
                              }
                              await _driverService.completeRide(
                                driverId: _authenticatedDriverId,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Ride marked completed! Driver is now available.'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: const Text('Complete Trip'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ] else if (_incomingRequests.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waiting for ride requests...',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                        Text(
                          'Available to receive nearby rider requests in real time',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _incomingRequests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ride = _incomingRequests[index];
                return _buildIncomingRideCard(ride);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncomingRideCard(RideModel ride) {
    final now = DateTime.now();
    final remainingSeconds = ride.expiresAt != null
        ? ride.expiresAt!.difference(now).inSeconds.clamp(0, 120)
        : 120;
    final elapsedSeconds = ride.requestedAt != null
        ? now.difference(ride.requestedAt!).inSeconds.clamp(0, 9999)
        : 0;

    double? distKm;
    if (_currentLat != null && _currentLng != null) {
      distKm = ValidatedLocation.distanceMeters(
            _currentLat!,
            _currentLng!,
            ride.pickupLatitude,
            ride.pickupLongitude,
          ) /
          1000.0;
    }

    final isAccepting = _acceptingRideIds.contains(ride.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZyroTheme.primaryColor.withValues(alpha: 0.3)),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Vehicle type, Fare, and Remaining Countdown
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getVehicleIcon(ride.rideType),
                  color: ZyroTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ZYRO ${ride.rideType.toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: ZyroTheme.darkCharcoal,
                      ),
                    ),
                    Text(
                      'Fare: ₹${ride.fare.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: ZyroTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              // 120s Countdown Remaining Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: remainingSeconds > 30
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: remainingSeconds > 30
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: remainingSeconds > 30
                          ? const Color(0xFFB45309)
                          : const Color(0xFFB91C1C),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${remainingSeconds}s remaining',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: remainingSeconds > 30
                            ? const Color(0xFFB45309)
                            : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: ZyroTheme.borderLight),

          // Telemetry details: Pickup & Destination coordinates + address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked_rounded,
                      size: 14, color: ZyroTheme.primaryColor),
                  Container(
                    width: 2,
                    height: 20,
                    color: ZyroTheme.borderLight,
                  ),
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: ZyroTheme.successGreen),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.pickupAddress != null && ride.pickupAddress!.isNotEmpty
                          ? '${ride.pickupAddress} (${ride.pickupLatitude.toStringAsFixed(4)}, ${ride.pickupLongitude.toStringAsFixed(4)})'
                          : 'Pickup: ${ride.pickupLatitude.toStringAsFixed(4)}, ${ride.pickupLongitude.toStringAsFixed(4)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ZyroTheme.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ride.destinationAddress != null &&
                              ride.destinationAddress!.isNotEmpty
                          ? '${ride.destinationAddress} (${ride.destinationLatitude.toStringAsFixed(4)}, ${ride.destinationLongitude.toStringAsFixed(4)})'
                          : 'Destination: ${ride.destinationLatitude.toStringAsFixed(4)}, ${ride.destinationLongitude.toStringAsFixed(4)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ZyroTheme.darkCharcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Metadata Row: Distance & Time Since Request & Status
          Row(
            children: [
              if (distKm != null) ...[
                const Icon(Icons.navigation_rounded,
                    size: 13, color: ZyroTheme.mutedText),
                const SizedBox(width: 4),
                Text(
                  '${distKm.toStringAsFixed(1)} km away',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ZyroTheme.mutedText,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              const Icon(Icons.access_time_rounded,
                  size: 13, color: ZyroTheme.mutedText),
              const SizedBox(width: 4),
              Text(
                'Requested ${elapsedSeconds}s ago',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: ZyroTheme.mutedText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Status: ${ride.status}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ZyroTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: DECLINE & ACCEPT RIDE
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _declineRide(ride),
                  icon: const Icon(Icons.close_rounded, size: 16, color: ZyroTheme.errorRed),
                  label: Text(
                    'Decline',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: ZyroTheme.errorRed,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: isAccepting ? null : () => _acceptRide(ride),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZyroTheme.darkCharcoal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isAccepting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: Color(0xFF86EFAC)),
                            const SizedBox(width: 8),
                            Text(
                              'Accept Ride',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverEarningsCard() {
    return StreamBuilder<List<RideModel>>(
      stream: _rideService.watchRidesForDriver(_authenticatedDriverId),
      builder: (context, snapshot) {
        final rides = snapshot.data ?? [];
        final completedRides =
            rides.where((r) => r.status == RideStatus.completed).toList();

        // Calculate today's earnings
        final now = DateTime.now();
        final todayRides = completedRides.where((r) {
          final completedAt = r.completedAt ?? r.requestedAt;
          return completedAt != null &&
              completedAt.year == now.year &&
              completedAt.month == now.month &&
              completedAt.day == now.day;
        }).toList();

        final todayEarnings =
            todayRides.fold<double>(0.0, (sum, r) => sum + r.fare);
        final totalEarnings =
            completedRides.fold<double>(0.0, (sum, r) => sum + r.fare);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ZyroTheme.softCardShadow,
            border: Border.all(color: ZyroTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      size: 18, color: ZyroTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Driver Earnings & Performance',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: ZyroTheme.darkCharcoal,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Live Cloud Data',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TODAY'S EARNINGS",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${todayEarnings.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                          Text(
                            '${todayRides.length} rides today',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ZyroTheme.isDarkMode(context)
                            ? ZyroTheme.surfaceDarkElevated
                            : ZyroTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ZyroTheme.borderColor(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ALL-TIME EARNINGS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ZyroTheme.mutedText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${totalEarnings.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ZyroTheme.textPrimary(context),
                            ),
                          ),
                          Text(
                            '${completedRides.length} total completed',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: ZyroTheme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDemoSeedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build_circle_outlined,
                  size: 18, color: Color(0xFFEA580C)),
              const SizedBox(width: 8),
              Text(
                'DEV ONLY: Candidate Pool Seeder',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: const Color(0xFF9A3412),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Initializes 5 candidate demo driver profiles in Firestore anchored around your real GPS for testing 120s matching and backup driver allocation.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: const Color(0xFFC2410C),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ZyroButton(
            text: _isSeedingDemo
                ? 'Seeding to Firestore...'
                : 'Seed Demo Driver Pool',
            isLoading: _isSeedingDemo,
            height: 44,
            icon: Icons.cloud_upload_rounded,
            onPressed: _isSeedingDemo ? null : _seedDemoDriversInFirestore,
          ),
        ],
      ),
    );
  }
}

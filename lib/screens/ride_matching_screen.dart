import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import '../services/demo_ride_allocation_service.dart';
import '../services/driver_service.dart';
import '../services/routing_service.dart';
import '../services/websocket_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/zyro_button.dart';
import '../widgets/zyro_map.dart';

class RideMatchingScreen extends StatefulWidget {
  final String pickupAddress;
  final String destinationAddress;
  final String rideType;
  final double fare;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final String riderId;

  const RideMatchingScreen({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.rideType,
    required this.fare,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    this.riderId = 'rider_demo_1',
  });

  @override
  State<RideMatchingScreen> createState() => _RideMatchingScreenState();
}

class _RideMatchingScreenState extends State<RideMatchingScreen>
    with SingleTickerProviderStateMixin {
  late final DemoRideAllocationService _allocationService;
  late final AnimationController _pulseController;

  final DriverService _driverService = DriverService();
  final RoutingService _routingService = RoutingService.instance;
  final WebSocketService _webSocketService = WebSocketService.instance;

  StreamSubscription<DriverModel?>? _assignedDriverSubscription;
  StreamSubscription<DriverLocationEvent>? _wsDriverLocationSubscription;
  StreamSubscription<RideAssignedEvent>? _wsRideAssignedSubscription;
  DriverModel? _realtimeAssignedDriver;
  double? _driverHeading;
  double? _driverSpeed;
  DateTime? _driverLastUpdated;
  List<LatLng>? _routePoints;
  String? _subscribedDriverId;
  String? _subscribedRideId;
  bool _isCancelling = false;

  Future<void> _handleCancelRide() async {
    if (_isCancelling) return;
    setState(() {
      _isCancelling = true;
    });

    // 1. Unsubscribe and cancel active streams
    if (_subscribedRideId != null) {
      _webSocketService.unsubscribeRide(_subscribedRideId!);
    }
    _wsDriverLocationSubscription?.cancel();
    _wsRideAssignedSubscription?.cancel();
    _assignedDriverSubscription?.cancel();
    _pulseController.stop();

    // 2. Authoritatively cancel in Firestore & local service
    try {
      await _allocationService.cancelRide();
    } catch (e) {
      debugPrint('[RideMatchingScreen] Error cancelling ride: $e');
    }

    if (!mounted) return;

    // 3. Close matching screen and return to Home
    Navigator.pop(context, 'cancelled');

    // 4. Present clear success confirmation to rider
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZyroTheme.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ride Cancelled: Your ride request has been cancelled.',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _allocationService = DemoRideAllocationService();
    _allocationService.addListener(_onAllocationStateChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fetchRoute();

    // Connect WebSocket and listen for driver updates
    _webSocketService.connect();
    _wsDriverLocationSubscription =
        _webSocketService.onDriverLocation.listen((loc) {
      if (!mounted) return;
      if (loc.rideId == _subscribedRideId ||
          (_subscribedDriverId != null && loc.driverId == _subscribedDriverId)) {
        setState(() {
          _driverHeading = loc.heading;
          _driverSpeed = loc.speed;
          _driverLastUpdated = DateTime.now();
          if (_realtimeAssignedDriver != null) {
            _realtimeAssignedDriver = _realtimeAssignedDriver!.copyWith(
              latitude: loc.latitude,
              longitude: loc.longitude,
            );
          } else {
            _realtimeAssignedDriver = DriverModel(
              id: loc.driverId,
              name: 'Assigned Driver',
              phone: '+91 98765 00000',
              vehicleNumber: 'AP 31 ZY 9999',
              vehicleType: widget.rideType,
              latitude: loc.latitude,
              longitude: loc.longitude,
              isOnline: true,
              isAvailable: false,
              averageRating: 4.9,
              completedRidesCount: 150,
            );
          }
        });
      }
    });

    _wsRideAssignedSubscription =
        _webSocketService.onRideAssigned.listen((event) {
      if (!mounted) return;
      if (event.rideId == _subscribedRideId || event.rideId == stateRideId) {
        setState(() {
          _subscribedDriverId = event.driverId;
        });
      }
    });

    // Start 120s search process
    _startMatchingProcess();
  }

  String? get stateRideId => _allocationService.state?.ride.id;

  Future<void> _startMatchingProcess() async {
    _allocationService.startRideAllocation(
      riderId: widget.riderId,
      pickupLatitude: widget.pickupLat,
      pickupLongitude: widget.pickupLng,
      destinationLatitude: widget.destLat,
      destinationLongitude: widget.destLng,
      rideType: widget.rideType,
      fare: widget.fare,
      pickupAddress: widget.pickupAddress,
      destinationAddress: widget.destinationAddress,
    );
  }

  Future<void> _fetchRoute() async {
    final route = await _routingService.getRoute(
      origin: LatLng(widget.pickupLat, widget.pickupLng),
      destination: LatLng(widget.destLat, widget.destLng),
    );
    if (mounted) {
      setState(() {
        _routePoints = route?.points;
      });
    }
  }

  void _onAllocationStateChanged() {
    if (!mounted) return;

    final state = _allocationService.state;

    // Manage WebSocket ride subscription
    if (state?.ride.id != null && state!.ride.id != _subscribedRideId) {
      if (_subscribedRideId != null) {
        _webSocketService.unsubscribeRide(_subscribedRideId!);
      }
      _subscribedRideId = state.ride.id;
      _webSocketService.subscribeRide(_subscribedRideId!);
    }

    final assignedDriverId = state?.ride.driverId ??
        state?.assignedDriver?.id ??
        (state?.ride.status == RideStatus.driverAssigned
            ? state?.backupDriver?.id
            : null);

    if (assignedDriverId != null &&
        assignedDriverId.isNotEmpty &&
        assignedDriverId != _subscribedDriverId) {
      _subscribedDriverId = assignedDriverId;
      _assignedDriverSubscription?.cancel();
      try {
        _assignedDriverSubscription =
            _driverService.watchDriver(assignedDriverId).listen((driver) {
          if (mounted) {
            setState(() {
              _realtimeAssignedDriver = driver;
            });
          }
        }, onError: (e) {
          debugPrint('[RideMatchingScreen] Watch driver stream error: $e');
        });
      } catch (e) {
        debugPrint('[RideMatchingScreen] Firestore stream unavailable: $e');
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    if (_subscribedRideId != null) {
      _webSocketService.unsubscribeRide(_subscribedRideId!);
    }
    _webSocketService.disconnect();
    _wsDriverLocationSubscription?.cancel();
    _wsRideAssignedSubscription?.cancel();
    _assignedDriverSubscription?.cancel();
    _allocationService.removeListener(_onAllocationStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getVehicleTitle(String rideType) {
    switch (rideType.toLowerCase()) {
      case 'bike':
        return 'ZYRO Bike';
      case 'auto':
        return 'ZYRO Auto';
      default:
        return 'ZYRO Prime Cab';
    }
  }

  IconData _getVehicleIcon(String rideType) {
    switch (rideType.toLowerCase()) {
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
    final state = _allocationService.state;

    if (state == null) {
      return Scaffold(
        backgroundColor: ZyroTheme.scaffoldBg(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isAssigned = state.ride.status == RideStatus.driverAssigned;
    final isNoDriver = state.ride.status == RideStatus.noDriver;
    final isCancelled = state.ride.status == RideStatus.cancelled;

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: ZyroTheme.cardBg(context),
        foregroundColor: ZyroTheme.textPrimary(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ZyroTheme.textPrimary(context)),
          onPressed: _isCancelling ? null : _handleCancelRide,
        ),
        title: Text(
          isAssigned
              ? 'Driver Confirmed'
              : (isNoDriver ? 'No Driver Available' : 'Matching Driver'),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: ZyroTheme.textPrimary(context),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trip Summary Header Card
              _buildTripSummaryCard(state),
              const SizedBox(height: 16),

              // Live OpenStreetMap with pickup, destination, route polyline, and assigned driver marker
              ZyroMap(
                height: 280,
                pickupLocation: LatLng(widget.pickupLat, widget.pickupLng),
                destinationLocation: LatLng(widget.destLat, widget.destLng),
                driverLocation: (isAssigned &&
                        _realtimeAssignedDriver != null &&
                        _realtimeAssignedDriver!.latitude != 0.0)
                    ? LatLng(
                        _realtimeAssignedDriver!.latitude,
                        _realtimeAssignedDriver!.longitude,
                      )
                    : (isAssigned && state.assignedDriver != null
                        ? LatLng(
                            state.assignedDriver!.latitude,
                            state.assignedDriver!.longitude,
                          )
                        : null),
                driverName: _realtimeAssignedDriver?.name ??
                    state.assignedDriver?.name ??
                    'Assigned Driver',
                driverHeading: _driverHeading,
                driverSpeed: _driverSpeed,
                driverLastUpdated: _driverLastUpdated,
                routePoints: _routePoints,
                autoTrackGps: false,
                showRecenterButton: true,
              ),
              const SizedBox(height: 16),

              // Countdown / Status Section
              if (!state.isCompleted) ...[
                _buildCountdownSection(state),
                const SizedBox(height: 16),
                _buildMandatoryBackupCard(state),
                const SizedBox(height: 16),
                _buildBroadcastingSection(state),
              ] else if (isAssigned) ...[
                _buildAssignedSuccessSection(state),
              ] else if (isNoDriver) ...[
                _buildNoDriverSection(),
              ] else if (isCancelled) ...[
                _buildCancelledSection(),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(state),
    );
  }

  Widget _buildTripSummaryCard(DemoRideState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: ZyroTheme.cardShadow(context),
        border: Border.all(color: ZyroTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurfaceAdaptive(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getVehicleIcon(widget.rideType),
                  color: ZyroTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getVehicleTitle(widget.rideType),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: ZyroTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fare: ₹${widget.fare.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: ZyroTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(state.ride.status),
            ],
          ),
          Divider(height: 24, color: ZyroTheme.borderColor(context)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked_rounded,
                      size: 16, color: ZyroTheme.primaryColor),
                  Container(
                    width: 2,
                    height: 24,
                    color: ZyroTheme.borderColor(context),
                  ),
                  const Icon(Icons.location_on_rounded,
                      size: 16, color: ZyroTheme.successGreen),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pickupAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ZyroTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.destinationAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ZyroTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case RideStatus.searching:
        bg = ZyroTheme.accentYellow.withValues(alpha: 0.15);
        fg = const Color(0xFFB78103);
        label = 'Searching';
        break;
      case RideStatus.driverAssigned:
        bg = ZyroTheme.successGreen.withValues(alpha: 0.15);
        fg = const Color(0xFF1B8A7E);
        label = 'Assigned';
        break;
      case RideStatus.noDriver:
        bg = ZyroTheme.errorRed.withValues(alpha: 0.15);
        fg = ZyroTheme.errorRed;
        label = 'No Driver';
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildCountdownSection(DemoRideState state) {
    final progress = state.remainingSeconds / 120.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: ZyroTheme.cardShadow(context),
        border: Border.all(color: ZyroTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: ZyroTheme.borderColor(context),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.25
                            ? ZyroTheme.primaryColor
                            : ZyroTheme.errorRed,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(state.remainingSeconds),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: ZyroTheme.textPrimary(context),
                        ),
                      ),
                      Text(
                        'sec',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ZyroTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '120s Allocation Window',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: ZyroTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Offering ride to nearby drivers. If none accept by 00:00, the mandatory backup driver is automatically assigned.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: ZyroTheme.textSecondary(context),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMandatoryBackupCard(DemoRideState state) {
    final backup = state.backupDriver;
    if (backup == null) return const SizedBox.shrink();

    final dist = state.driverDistancesKm[backup.id] ?? 1.2;
    final isDark = ZyroTheme.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F291E) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF166534) : const Color(0xFF86EFAC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'MANDATORY BACKUP DRIVER',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Auto-assigned at 00:00',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDark ? const Color(0xFF166534) : const Color(0xFFDCFCE7),
                child: Text(
                  backup.name.substring(0, 1),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF15803D),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backup.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: ZyroTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${backup.vehicleNumber} • ${dist.toStringAsFixed(1)} km away',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: ZyroTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? ZyroTheme.surfaceDarkElevated : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZyroTheme.borderColor(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Selected by algorithm: Most recent completed trip',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastingSection(DemoRideState state) {
    final isDark = ZyroTheme.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZyroTheme.borderColor(context)),
        boxShadow: ZyroTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZyroTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Broadcasting Ride Request',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: ZyroTheme.textPrimary(context),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurfaceAdaptive(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.eligibleDrivers.length} Drivers Offered',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ZyroTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dispatched in real-time to nearby eligible drivers. First driver to accept is assigned immediately.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: ZyroTheme.textSecondary(context),
              height: 1.35,
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 6),
                title: Text(
                  'View Eligible Driver Candidates (${state.eligibleDrivers.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ZyroTheme.primaryColor,
                  ),
                ),
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.eligibleDrivers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final driver = state.eligibleDrivers[index];
                    final dist = state.driverDistancesKm[driver.id] ?? 1.0;
                    final isBackup = state.backupDriver?.id == driver.id;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isBackup
                            ? (isDark ? const Color(0xFF0F291E) : const Color(0xFFF0FDF4))
                            : (isDark ? ZyroTheme.surfaceDarkElevated : ZyroTheme.backgroundLight),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isBackup
                              ? (isDark ? const Color(0xFF166534) : const Color(0xFF86EFAC))
                              : ZyroTheme.borderColor(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getVehicleIcon(driver.vehicleType),
                            size: 18,
                            color: isBackup
                                ? const Color(0xFF16A34A)
                                : ZyroTheme.primaryColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      driver.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: ZyroTheme.textPrimary(context),
                                      ),
                                    ),
                                    if (isBackup) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF166534) : const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '120s Backup',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${driver.vehicleNumber} • ${dist.toStringAsFixed(1)} km away',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: ZyroTheme.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    ZyroTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Offered',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: ZyroTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  }

  Widget _buildAssignedSuccessSection(DemoRideState state) {
    final driver = state.assignedDriver ??
        state.backupDriver ??
        state.eligibleDrivers.first;
    final isBackupAssigned = state.assignmentReason == 'backup_auto_assigned';
    final isDark = ZyroTheme.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: ZyroTheme.cardShadow(context),
        border: Border.all(
          color: isDark ? const Color(0xFF166534) : const Color(0xFF86EFAC),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF166534) : const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isBackupAssigned
                ? 'Mandatory Backup Auto-Assigned!'
                : 'Driver Assigned!',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: ZyroTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isBackupAssigned
                  ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                  : (isDark ? const Color(0xFF0F291E) : const Color(0xFFDCFCE7)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isBackupAssigned
                  ? '⚡ Assigned via 120s Timeout Automatic Allocation'
                  : '⚡ Assigned via First Driver Acceptance',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isBackupAssigned
                    ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                    : (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534)),
              ),
            ),
          ),
          Divider(height: 32, color: ZyroTheme.borderColor(context)),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: ZyroTheme.primarySurfaceAdaptive(context),
                child: Text(
                  driver.name.substring(0, 1),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: ZyroTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: ZyroTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      driver.vehicleNumber,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: ZyroTheme.textSecondary(context),
                      ),
                    ),
                    Text(
                      driver.phone,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: ZyroTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurfaceAdaptive(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'OTP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ZyroTheme.textSecondary(context),
                      ),
                    ),
                    Text(
                      '4829',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ZyroTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoDriverSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: ZyroTheme.cardShadow(context),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: ZyroTheme.errorRed),
          const SizedBox(height: 12),
          Text(
            'No Drivers Available',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: ZyroTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All nearby drivers are currently busy. Please try again in a few moments.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: ZyroTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: ZyroTheme.cardShadow(context),
        border: Border.all(color: ZyroTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cancel_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'Ride Request Cancelled',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: ZyroTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomActions(DemoRideState state) {
    if (!state.isCompleted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ZyroTheme.cardBg(context),
          border: Border(top: BorderSide(color: ZyroTheme.borderColor(context))),
          boxShadow: ZyroTheme.cardShadow(context),
        ),
        child: OutlinedButton(
          onPressed: _isCancelling ? null : _handleCancelRide,
          style: OutlinedButton.styleFrom(
            foregroundColor: ZyroTheme.errorRed,
            side: const BorderSide(color: ZyroTheme.errorRed),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isCancelling
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(ZyroTheme.errorRed),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Cancelling Ride...',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ZyroTheme.errorRed,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Cancel Ride Request',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ZyroTheme.errorRed,
                  ),
                ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        border: Border(top: BorderSide(color: ZyroTheme.borderColor(context))),
        boxShadow: ZyroTheme.cardShadow(context),
      ),
      child: ZyroButton(
        text: 'Back to Home',
        onPressed: () {
          _allocationService.reset();
          Navigator.pop(context);
        },
      ),
    );
  }
}

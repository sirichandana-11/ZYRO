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
  final RoutingService _routingService = OsrmRoutingService();
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
              vehicleType: widget.rideType,
              vehicleNumber: 'ZYRO-LIVE',
              isOnline: true,
              isAvailable: false,
              latitude: loc.latitude,
              longitude: loc.longitude,
            );
          }
        });
      }
    });

    _wsRideAssignedSubscription =
        _webSocketService.onRideAssigned.listen((assigned) {
      if (!mounted) return;
      if (assigned.rideId == _subscribedRideId) {
        setState(() {
          _subscribedDriverId = assigned.driverId;
          _realtimeAssignedDriver = DriverModel(
            id: assigned.driverId,
            name: assigned.driverName,
            phone: assigned.driverPhone ?? '+91 98765 00000',
            vehicleType: assigned.vehicleType ?? widget.rideType,
            vehicleNumber: assigned.vehicleNumber ?? 'ZYRO-101',
            isOnline: true,
            isAvailable: false,
            latitude: assigned.latitude != 0.0 ? assigned.latitude : widget.pickupLat,
            longitude: assigned.longitude != 0.0 ? assigned.longitude : widget.pickupLng,
          );
        });
      }
    });

    // Start 120-second allocation
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
      _assignedDriverSubscription =
          _driverService.watchDriver(assignedDriverId).listen((driver) {
        if (mounted) {
          setState(() {
            _realtimeAssignedDriver = driver;
          });
        }
      });
    }

    setState(() {});
  }

  @override
  void dispose() {
    if (_subscribedRideId != null) {
      _webSocketService.unsubscribeRide(_subscribedRideId!);
    }
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAssigned = state.ride.status == RideStatus.driverAssigned;
    final isNoDriver = state.ride.status == RideStatus.noDriver;
    final isCancelled = state.ride.status == RideStatus.cancelled;

    return Scaffold(
      backgroundColor: ZyroTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ZyroTheme.darkCharcoal),
          onPressed: () {
            _allocationService.cancelRide();
            Navigator.pop(context);
          },
        ),
        title: Text(
          isAssigned
              ? 'Driver Confirmed'
              : (isNoDriver ? 'No Driver Available' : 'Matching Driver'),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: ZyroTheme.darkCharcoal,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ZyroTheme.softCardShadow,
        border: Border.all(color: ZyroTheme.borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurface,
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
                        color: ZyroTheme.darkCharcoal,
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
          const Divider(height: 24, color: ZyroTheme.borderLight),
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
                    color: ZyroTheme.borderLight,
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
                        color: ZyroTheme.darkCharcoal,
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
                        color: ZyroTheme.darkCharcoal,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ZyroTheme.softCardShadow,
        border: Border.all(color: ZyroTheme.borderLight),
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
                      backgroundColor: ZyroTheme.borderLight,
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
                          color: ZyroTheme.darkCharcoal,
                        ),
                      ),
                      Text(
                        'sec',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ZyroTheme.mutedText,
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
                        color: ZyroTheme.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Offering ride to nearby drivers. If none accept by 00:00, the mandatory backup driver is automatically assigned.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: ZyroTheme.bodyText,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
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
                  color: const Color(0xFF15803D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFDCFCE7),
                child: Text(
                  backup.name.substring(0, 1),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF15803D),
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
                        color: ZyroTheme.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${backup.vehicleNumber} • ${dist.toStringAsFixed(1)} km away',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: ZyroTheme.bodyText,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
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
                      color: const Color(0xFF166534),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZyroTheme.borderLight),
        boxShadow: ZyroTheme.softCardShadow,
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
              color: ZyroTheme.bodyText,
              height: 1.35,
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
                            ? const Color(0xFFF0FDF4)
                            : ZyroTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isBackup
                              ? const Color(0xFF86EFAC)
                              : ZyroTheme.borderLight,
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
                                        color: ZyroTheme.darkCharcoal,
                                      ),
                                    ),
                                    if (isBackup) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '120s Backup',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF15803D),
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
                                    color: ZyroTheme.mutedText,
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
                                  color: ZyroTheme.mutedText,
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
        ],
      ),
    );
  }

  Widget _buildAssignedSuccessSection(DemoRideState state) {
    final driver = state.assignedDriver ??
        state.backupDriver ??
        state.eligibleDrivers.first;
    final isBackupAssigned = state.assignmentReason == 'backup_auto_assigned';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ZyroTheme.softCardShadow,
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
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
              color: ZyroTheme.darkCharcoal,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isBackupAssigned
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFDCFCE7),
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
                    ? const Color(0xFF92400E)
                    : const Color(0xFF166534),
              ),
            ),
          ),
          const Divider(height: 32, color: ZyroTheme.borderLight),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: ZyroTheme.primarySurface,
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
                        color: ZyroTheme.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      driver.vehicleNumber,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: ZyroTheme.bodyText,
                      ),
                    ),
                    Text(
                      driver.phone,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: ZyroTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'OTP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ZyroTheme.mutedText,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ZyroTheme.softCardShadow,
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
              color: ZyroTheme.darkCharcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All nearby drivers are currently busy. Please try again in a few moments.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: ZyroTheme.bodyText,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ZyroTheme.softCardShadow,
        border: Border.all(color: ZyroTheme.borderLight),
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
              color: ZyroTheme.darkCharcoal,
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
          color: Colors.white,
          border: const Border(top: BorderSide(color: ZyroTheme.borderLight)),
          boxShadow: ZyroTheme.softCardShadow,
        ),
        child: OutlinedButton(
          onPressed: () {
            _allocationService.cancelRide();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: ZyroTheme.errorRed,
            side: const BorderSide(color: ZyroTheme.errorRed),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
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
        color: Colors.white,
        border: const Border(top: BorderSide(color: ZyroTheme.borderLight)),
        boxShadow: ZyroTheme.softCardShadow,
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

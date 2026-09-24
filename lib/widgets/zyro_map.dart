import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/coordinate.dart';
import '../models/validated_location.dart';
import '../services/location_service.dart';
import '../theme/zyro_theme.dart';
import 'location_debug_panel.dart';

enum MapFollowMode {
  followingUser,
  userMovedMap,
  followDisabled,
}

/// Production-Grade OpenStreetMap Map Widget for ZYRO.
class ZyroMap extends StatefulWidget {
  final double? height;
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final LatLng? driverLocation;
  final String? driverName;
  final double? driverHeading;
  final double? driverSpeed;
  final DateTime? driverLastUpdated;
  final List<LatLng>? routePoints;
  final bool isDriverMode;
  final bool showLiveLocationBadge;
  final bool showZoomControls;
  final bool showRecenterButton;
  final bool showDebugPanel;
  final bool autoTrackGps;
  final EdgeInsets? cameraPadding;
  final double? bottomControlsPadding;
  final ValueChanged<ValidatedLocation>? onLocationUpdated;
  final VoidCallback? onTap;
  final ValueChanged<LatLng>? onMapTap;

  const ZyroMap({
    super.key,
    this.height = 240,
    this.pickupLocation,
    this.destinationLocation,
    this.driverLocation,
    this.driverName,
    this.driverHeading,
    this.driverSpeed,
    this.driverLastUpdated,
    this.routePoints,
    this.isDriverMode = false,
    this.showLiveLocationBadge = true,
    this.showZoomControls = true,
    this.showRecenterButton = true,
    this.showDebugPanel = true,
    this.autoTrackGps = true,
    this.cameraPadding,
    this.bottomControlsPadding,
    this.onLocationUpdated,
    this.onTap,
    this.onMapTap,
  });

  @override
  State<ZyroMap> createState() => _ZyroMapState();
}

class _ZyroMapState extends State<ZyroMap> with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  ValidatedLocation? _currentValidatedLocation;
  LocationServiceStatus _status = LocationServiceStatus.ready;
  String? _statusMessage;
  bool _isLoadingGps = true;
  bool _isMapReady = false;

  MapFollowMode _followMode = MapFollowMode.followingUser;
  LatLng? _pendingTargetCenter;

  StreamSubscription<ValidatedLocation>? _locationSubscription;

  // Driver Marker Animation & Interpolation
  AnimationController? _driverAnimController;
  Animation<LatLng>? _driverPositionAnim;
  LatLng? _previousDriverLocation;

  static const double _defaultZoom = 15.5;

  @override
  void initState() {
    super.initState();

    _driverAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    if (widget.autoTrackGps) {
      _initializeLocation();
    } else {
      _isLoadingGps = false;
      _followMode = MapFollowMode.followDisabled;
    }
  }

  @override
  void didUpdateWidget(covariant ZyroMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Driver location interpolation
    if (widget.driverLocation != null &&
        widget.driverLocation != oldWidget.driverLocation) {
      _animateDriverMarker(widget.driverLocation!);
    }

    // If route or explicit locations changed, fit bounds
    if (widget.routePoints != oldWidget.routePoints ||
        widget.destinationLocation != oldWidget.destinationLocation ||
        widget.pickupLocation != oldWidget.pickupLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBoundsIfNecessary();
      });
    }
  }

  void _animateDriverMarker(LatLng newTarget) {
    if (!Coordinate.isValid(newTarget.latitude, newTarget.longitude)) return;

    final start = _previousDriverLocation ??
        (widget.driverLocation != null
            ? widget.driverLocation!
            : newTarget);

    _previousDriverLocation = newTarget;

    _driverPositionAnim = LatLngTween(begin: start, end: newTarget).animate(
      CurvedAnimation(
        parent: _driverAnimController!,
        curve: Curves.easeOutCubic,
      ),
    );

    _driverAnimController!.forward(from: 0.0);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _driverAnimController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoadingGps = true;
    });

    final result = await _locationService.determinePosition();

    if (!mounted) return;

    if (result.isSuccess && result.validatedLocation != null) {
      _onValidatedLocationReceived(result.validatedLocation!, moveCamera: true);
      _subscribeToSharedLocationStream();
      setState(() {
        _status = LocationServiceStatus.ready;
        _isLoadingGps = false;
      });
    } else {
      setState(() {
        _status = result.status;
        _statusMessage = result.message;
        _isLoadingGps = false;
      });
    }
  }

  void _subscribeToSharedLocationStream() {
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.validatedLocationStream.listen(
      (ValidatedLocation loc) {
        if (!mounted) return;
        _onValidatedLocationReceived(loc, moveCamera: false);
      },
      onError: (e) {
        debugPrint('[ZyroMap] Location stream error: $e');
      },
    );
  }

  void _onValidatedLocationReceived(
    ValidatedLocation loc, {
    bool moveCamera = false,
  }) {
    setState(() {
      _currentValidatedLocation = loc;
    });

    widget.onLocationUpdated?.call(loc);

    final LatLng newPos = LatLng(loc.latitude, loc.longitude);

    // Apply pending location or move camera
    if (_isMapReady) {
      if ((moveCamera || _followMode == MapFollowMode.followingUser) &&
          widget.routePoints == null &&
          widget.destinationLocation == null) {
        _mapController.move(newPos, _defaultZoom);
      }
    } else {
      _pendingTargetCenter = newPos;
    }
  }

  void _recenterOnUser() {
    setState(() {
      _followMode = MapFollowMode.followingUser;
    });

    if (_currentValidatedLocation != null && _isMapReady) {
      _mapController.move(
        LatLng(_currentValidatedLocation!.latitude, _currentValidatedLocation!.longitude),
        _defaultZoom,
      );
    } else {
      _initializeLocation();
    }
  }

  void _zoomIn() {
    if (!_isMapReady) return;
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1.0);
  }

  void _zoomOut() {
    if (!_isMapReady) return;
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1.0);
  }

  void _fitBoundsIfNecessary() {
    if (!_isMapReady) return;

    final List<LatLng> allPoints = [];

    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      allPoints.addAll(widget.routePoints!);
    } else {
      if (widget.pickupLocation != null &&
          Coordinate.isValid(widget.pickupLocation!.latitude, widget.pickupLocation!.longitude)) {
        allPoints.add(widget.pickupLocation!);
      }
      if (widget.destinationLocation != null &&
          Coordinate.isValid(widget.destinationLocation!.latitude, widget.destinationLocation!.longitude)) {
        allPoints.add(widget.destinationLocation!);
      }
      if (widget.driverLocation != null &&
          Coordinate.isValid(widget.driverLocation!.latitude, widget.driverLocation!.longitude)) {
        allPoints.add(widget.driverLocation!);
      }
    }

    if (allPoints.length >= 2) {
      _followMode = MapFollowMode.followDisabled;
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: widget.cameraPadding ??
              const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
        ),
      );
    } else if (allPoints.length == 1) {
      _mapController.move(allPoints.first, _defaultZoom);
    }
  }

  LatLng? _getInitialCameraCenter() {
    if (widget.pickupLocation != null &&
        Coordinate.isValid(widget.pickupLocation!.latitude, widget.pickupLocation!.longitude)) {
      return widget.pickupLocation;
    }
    if (widget.driverLocation != null &&
        widget.isDriverMode &&
        Coordinate.isValid(widget.driverLocation!.latitude, widget.driverLocation!.longitude)) {
      return widget.driverLocation;
    }
    if (_currentValidatedLocation != null &&
        Coordinate.isValid(_currentValidatedLocation!.latitude, _currentValidatedLocation!.longitude)) {
      return LatLng(_currentValidatedLocation!.latitude, _currentValidatedLocation!.longitude);
    }
    // Zero fake geographic fallbacks: return null / pending
    return null;
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];

    // 1. Current User GPS Location Dot (when pickup is not explicitly placed elsewhere)
    if (_currentValidatedLocation != null &&
        widget.pickupLocation == null &&
        !widget.isDriverMode) {
      markers.add(
        Marker(
          point: LatLng(
            _currentValidatedLocation!.latitude,
            _currentValidatedLocation!.longitude,
          ),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: _buildUserLocationMarker(_currentValidatedLocation!),
        ),
      );
    }

    // 2. Pickup Marker
    if (widget.pickupLocation != null) {
      markers.add(
        Marker(
          point: widget.pickupLocation!,
          width: 80,
          height: 60,
          alignment: Alignment.bottomCenter,
          child: _buildPickupMarker(),
        ),
      );
    }

    // 3. Destination Marker
    if (widget.destinationLocation != null) {
      markers.add(
        Marker(
          point: widget.destinationLocation!,
          width: 80,
          height: 60,
          alignment: Alignment.bottomCenter,
          child: _buildDestinationMarker(),
        ),
      );
    }

    // 4. Assigned Driver Marker (Animated)
    if (widget.driverLocation != null) {
      final animatedPoint = _driverPositionAnim?.value ?? widget.driverLocation!;
      markers.add(
        Marker(
          point: animatedPoint,
          width: 96,
          height: 70,
          alignment: Alignment.center,
          child: _buildDriverMarker(
            widget.driverName ?? 'Driver',
            heading: widget.driverHeading ?? 0.0,
            speed: widget.driverSpeed ?? 0.0,
            lastUpdated: widget.driverLastUpdated,
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildUserLocationMarker(ValidatedLocation loc) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing Accuracy Ring
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ZyroTheme.primaryColor.withValues(alpha: 0.22),
          ),
        ),
        // Core Dot
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ZyroTheme.primaryColor,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPickupMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: ZyroTheme.darkCharcoal,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'Pickup',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: ZyroTheme.successGreen,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.my_location_rounded,
            color: Colors.white,
            size: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: ZyroTheme.primaryColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'Drop-off',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Colors.white,
            size: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverMarker(
    String name, {
    double heading = 0.0,
    double speed = 0.0,
    DateTime? lastUpdated,
  }) {
    final bool isStale = lastUpdated != null &&
        DateTime.now().difference(lastUpdated).inSeconds > 15;

    final bool rotateHeading = speed > 1.0 && heading > 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: isStale ? const Color(0xFFFEF3C7) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isStale ? const Color(0xFFD97706) : ZyroTheme.primaryColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isStale ? '⏳' : '🛵', style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isStale ? '$name (stale)' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isStale ? const Color(0xFF92400E) : ZyroTheme.darkCharcoal,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Transform.rotate(
          angle: rotateHeading ? (heading * (3.14159 / 180.0)) : 0.0,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: isStale
                  ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                  : ZyroTheme.brandGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: ZyroTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _getInitialCameraCenter();

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ZyroTheme.borderLight),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // 1. OpenStreetMap
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter ?? const LatLng(0.0, 0.0),
                initialZoom: initialCenter != null ? _defaultZoom : 2.0,
                minZoom: 2.0,
                maxZoom: 19.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture && _followMode == MapFollowMode.followingUser) {
                    setState(() {
                      _followMode = MapFollowMode.userMovedMap;
                    });
                  }
                },
                onMapReady: () {
                  setState(() {
                    _isMapReady = true;
                  });

                  if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
                    _fitBoundsIfNecessary();
                  } else if (_pendingTargetCenter != null) {
                    _mapController.move(_pendingTargetCenter!, _defaultZoom);
                    _pendingTargetCenter = null;
                  } else if (initialCenter != null) {
                    _mapController.move(initialCenter, _defaultZoom);
                  }
                },
                onTap: (tapPosition, point) {
                  widget.onTap?.call();
                  widget.onMapTap?.call(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zyro.app',
                  tileProvider: NetworkTileProvider(),
                  maxZoom: 19,
                ),
                if (widget.routePoints != null && widget.routePoints!.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.routePoints!,
                        strokeWidth: 6.0,
                        color: ZyroTheme.primaryColor.withValues(alpha: 0.35),
                      ),
                      Polyline(
                        points: widget.routePoints!,
                        strokeWidth: 4.0,
                        color: ZyroTheme.primaryColor,
                      ),
                    ],
                  ),
                AnimatedBuilder(
                  animation: _driverAnimController ?? const AlwaysStoppedAnimation(0),
                  builder: (context, _) => MarkerLayer(markers: _buildMarkers()),
                ),
              ],
            ),

            // 2. OpenStreetMap Attribution (Bottom-Left)
            Positioned(
              bottom: 6,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: ZyroTheme.darkCharcoal.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),

            // 3. Loading GPS Overlay (Zero fake fallbacks)
            if (_isLoadingGps && initialCenter == null)
              Container(
                color: Colors.white.withValues(alpha: 0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ZyroTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Acquiring real device GPS...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ZyroTheme.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. GPS / Permission Error Overlay
            if (!_isLoadingGps && _status != LocationServiceStatus.ready)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white.withValues(alpha: 0.95),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _status == LocationServiceStatus.serviceDisabled
                            ? Icons.location_off_rounded
                            : Icons.lock_outline_rounded,
                        size: 34,
                        color: ZyroTheme.primaryColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _status == LocationServiceStatus.serviceDisabled
                            ? 'GPS is Turned Off'
                            : 'Location Permission Needed',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ZyroTheme.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusMessage ?? 'Please allow location access to use maps & dispatch rides.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: ZyroTheme.mutedText,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (_status == LocationServiceStatus.serviceDisabled) {
                            await _locationService.openLocationSettings();
                          } else if (_status == LocationServiceStatus.permissionPermanentlyDenied) {
                            await _locationService.openAppSettings();
                          } else {
                            await _initializeLocation();
                          }
                        },
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          _status == LocationServiceStatus.permissionPermanentlyDenied
                              ? 'Open Settings'
                              : 'Enable Location',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZyroTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Live GPS Active Badge (Top-Left)
            if (widget.showLiveLocationBadge &&
                _status == LocationServiceStatus.ready &&
                !_isLoadingGps)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ZyroTheme.cardBg(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ZyroTheme.borderColor(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: ZyroTheme.successGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isDriverMode ? 'Driver GPS Active' : 'Real GPS Active',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: ZyroTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 6. Floating Recenter & Zoom Controls
            Positioned(
              bottom: widget.bottomControlsPadding ?? 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showZoomControls) ...[
                    _buildFloatingButton(
                      context: context,
                      icon: Icons.add_rounded,
                      onTap: _zoomIn,
                      tooltip: 'Zoom In',
                    ),
                    const SizedBox(height: 6),
                    _buildFloatingButton(
                      context: context,
                      icon: Icons.remove_rounded,
                      onTap: _zoomOut,
                      tooltip: 'Zoom Out',
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (widget.showRecenterButton && _status == LocationServiceStatus.ready)
                    _buildFloatingButton(
                      context: context,
                      icon: Icons.my_location_rounded,
                      onTap: _recenterOnUser,
                      tooltip: 'Recenter on Real GPS',
                      iconColor: _followMode == MapFollowMode.followingUser
                          ? ZyroTheme.primaryColor
                          : ZyroTheme.mutedText,
                    ),
                ],
              ),
            ),

            // 7. Development Diagnostics HUD Panel
            if (widget.showDebugPanel)
              LocationDebugPanel(
                location: _currentValidatedLocation,
                mapCenter: _isMapReady ? _mapController.camera.center : null,
                pickupLocation: widget.pickupLocation,
                destinationLocation: widget.destinationLocation,
                driverLocationTime: widget.driverLastUpdated,
                isMapReady: _isMapReady,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? iconColor,
  }) {
    final effectiveIconColor = iconColor ?? ZyroTheme.textPrimary(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ZyroTheme.cardBg(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZyroTheme.borderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: effectiveIconColor,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper LatLngTween for smooth marker animation
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end})
      : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    final lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final lng = begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return LatLng(lat, lng);
  }
}

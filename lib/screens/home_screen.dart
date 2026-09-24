import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/coordinate.dart';
import '../models/saved_place_model.dart';
import '../models/validated_location.dart';
import '../services/auth_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/saved_places_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/ride_option_card.dart';
import '../widgets/zyro_button.dart';
import '../widgets/zyro_map.dart';
import 'ride_matching_screen.dart';

class HomeScreen extends StatefulWidget {
  final User? user;
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onNavigateToTrips;

  const HomeScreen({
    super.key,
    this.user,
    this.onNavigateToProfile,
    this.onNavigateToTrips,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _pickupController =
      TextEditingController(text: 'Locating current position...');
  final TextEditingController _destinationController =
      TextEditingController();

  final LocationService _locationService = LocationService();
  final GeocodingService _geocodingService = GeocodingService.instance;
  final RoutingService _routingService = RoutingService.instance;
  final SavedPlacesService _savedPlacesService = SavedPlacesService();

  ValidatedLocation? _currentRiderPosition;
  LatLng? _pickupLatLng;
  LatLng? _destLatLng;
  List<LatLng>? _routePoints;
  RouteResult? _routeResult;
  bool _isRouting = false;
  bool _isLocating = true;
  bool _isManualPickup = false;

  String _selectedRideId = 'bike';
  bool _isBooking = false;

  final List<RideOption> _rideOptions = const [
    RideOption(
      id: 'bike',
      name: 'ZYRO Bike',
      tagline: 'Fastest in traffic',
      fare: '₹--',
      eta: '2 mins',
      icon: Icons.two_wheeler_rounded,
      iconColor: ZyroTheme.primaryColor,
      capacity: '1',
    ),
    RideOption(
      id: 'auto',
      name: 'ZYRO Auto',
      tagline: 'Comfortable & reliable',
      fare: '₹--',
      eta: '3 mins',
      icon: Icons.electric_rickshaw_rounded,
      iconColor: ZyroTheme.accentYellow,
      capacity: '3',
    ),
    RideOption(
      id: 'cab',
      name: 'ZYRO Prime Cab',
      tagline: 'AC ride with top drivers',
      fare: '₹--',
      eta: '4 mins',
      icon: Icons.directions_car_rounded,
      iconColor: Color(0xFF2A9D8F),
      capacity: '4',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initGpsLocation();
  }

  Future<void> _initGpsLocation() async {
    setState(() {
      _isLocating = true;
    });

    final result = await _locationService.determinePosition();
    if (!mounted) return;

    if (result.isSuccess && result.validatedLocation != null) {
      _onRiderLocationUpdated(result.validatedLocation!);
    } else {
      setState(() {
        _isLocating = false;
        if (_pickupLatLng == null) {
          _pickupController.text = 'Unable to determine GPS location';
        }
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  double _haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Calculates the fare from the actual OSRM road distance.
  double? _calculateFare(String rideId) {
    final distanceKm = _routeResult?.distanceKm;
    if (distanceKm == null) return null;

    double baseFare;
    double perKm;

    switch (rideId) {
      case 'bike':
        baseFare = 10;
        perKm = 5;
        break;
      case 'auto':
        baseFare = 15;
        perKm = 5;
        break;
      case 'cab':
        baseFare = 20;
        perKm = 10;
        break;
      default:
        baseFare = 15;
        perKm = 5;
    }

    return (baseFare + (distanceKm * perKm)).roundToDouble();
  }

  String _formattedFare(String rideId) {
    final fare = _calculateFare(rideId);
    if (fare == null) return '₹--';
    return '₹${fare.toStringAsFixed(0)}';
  }

  void _onRiderLocationUpdated(ValidatedLocation location) {
    if (!Coordinate.isValid(location.latitude, location.longitude)) return;

    final isFirstLock = _currentRiderPosition == null;

    setState(() {
      _currentRiderPosition = location;
      _isLocating = false;

      if (!_isManualPickup || _pickupLatLng == null) {
        _pickupLatLng = LatLng(location.latitude, location.longitude);
      }
    });

    if (isFirstLock && !_isManualPickup) {
      _resolvePickupAddress(location.latitude, location.longitude);
    }

    if (_destLatLng != null) {
      _updateRoute();
    }
  }

  Future<void> _resolvePickupAddress(double lat, double lng) async {
    try {
      final address = await _geocodingService.reverseGeocode(lat, lng);
      if (!mounted) return;
      if (address != null && address.isNotEmpty) {
        setState(() {
          _pickupController.text = address;
        });
      } else {
        setState(() {
          _pickupController.text =
              'Current GPS (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickupController.text =
            'Current GPS (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
      });
    }
  }

  Future<void> _updateRoute() async {
    final origin = _pickupLatLng ??
        (_currentRiderPosition != null
            ? LatLng(_currentRiderPosition!.latitude, _currentRiderPosition!.longitude)
            : null);

    if (origin == null || _destLatLng == null) return;

    // Validate coordinates
    if (!Coordinate.isValid(origin.latitude, origin.longitude) ||
        !Coordinate.isValid(_destLatLng!.latitude, _destLatLng!.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid GPS coordinates detected. Please select a valid location.'),
          backgroundColor: ZyroTheme.errorRed,
        ),
      );
      return;
    }

    // PART 5: Prevent identical pickup and destination routes
    final distanceKm = _haversineDistanceKm(
      origin.latitude,
      origin.longitude,
      _destLatLng!.latitude,
      _destLatLng!.longitude,
    );

    if (distanceKm < 0.02) {
      // Under 20 meters
      setState(() {
        _destLatLng = null;
        _destinationController.clear();
        _routeResult = null;
        _routePoints = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please choose a different destination. Pickup and destination cannot be identical.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ZyroTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isRouting = true;
    });

    final route = await _routingService.getRoute(
      origin: origin,
      destination: _destLatLng!,
    );

    if (!mounted) return;

    setState(() {
      _isRouting = false;
      _routeResult = route;
      _routePoints = route?.points;
    });
  }

  void _selectSavedPlace(SavedPlaceModel place) {
    if (!Coordinate.isValid(place.latitude, place.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected saved place has invalid coordinates.')),
      );
      return;
    }

    setState(() {
      _destinationController.text = place.address.isNotEmpty ? place.address : place.title;
      _destLatLng = LatLng(place.latitude, place.longitude);
    });
    _updateRoute();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Set destination to ${place.title}',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openLocationSelectionSheet({required bool isPickup}) async {
    final authService = AuthService();
    final currentUser = widget.user ?? authService.currentUser;
    final currentUid = currentUser?.uid ?? '';

    final result = await showModalBottomSheet<_SelectedLocationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationSelectionSheet(
        isPickup: isPickup,
        uid: currentUid,
        currentPosition: _currentRiderPosition,
        geocodingService: _geocodingService,
        savedPlacesService: _savedPlacesService,
      ),
    );

    if (!mounted || result == null) return;

    if (result.isUseCurrentGps) {
      if (isPickup) {
        setState(() {
          _isManualPickup = false;
          if (_currentRiderPosition != null) {
            _pickupLatLng = LatLng(
              _currentRiderPosition!.latitude,
              _currentRiderPosition!.longitude,
            );
          }
        });
        if (_currentRiderPosition != null) {
          _resolvePickupAddress(
            _currentRiderPosition!.latitude,
            _currentRiderPosition!.longitude,
          );
        }
      } else {
        if (_currentRiderPosition != null) {
          setState(() {
            _destinationController.text =
                'Current GPS Location (${_currentRiderPosition!.latitude.toStringAsFixed(4)}, ${_currentRiderPosition!.longitude.toStringAsFixed(4)})';
            _destLatLng = LatLng(
              _currentRiderPosition!.latitude,
              _currentRiderPosition!.longitude,
            );
          });
        }
      }
      if (_destLatLng != null) {
        _updateRoute();
      }
    } else if (result.latLng != null && Coordinate.isValid(result.latLng!.latitude, result.latLng!.longitude)) {
      if (isPickup) {
        setState(() {
          _isManualPickup = true;
          _pickupController.text = result.address;
          _pickupLatLng = result.latLng;
        });
        if (_destLatLng != null) {
          _updateRoute();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pickup set to ${result.title}'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _destinationController.text = result.address;
          _destLatLng = result.latLng;
        });
        _updateRoute();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Destination set to ${result.title}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleMapTap(LatLng point) async {
    if (!Coordinate.isValid(point.latitude, point.longitude)) return;

    setState(() {
      _destinationController.text =
          'Pinned Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
      _destLatLng = point;
    });

    _updateRoute();

    try {
      final address = await _geocodingService.reverseGeocode(
        point.latitude,
        point.longitude,
      );
      if (mounted && address != null && address.isNotEmpty) {
        setState(() {
          _destinationController.text = address;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleBooking() async {
    if (_destLatLng == null && _destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select or choose a destination first.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ZyroTheme.primaryColor,
        ),
      );
      _openLocationSelectionSheet(isPickup: false);
      return;
    }

    final double? rawPickupLat =
        _pickupLatLng?.latitude ?? _currentRiderPosition?.latitude;
    final double? rawPickupLng =
        _pickupLatLng?.longitude ?? _currentRiderPosition?.longitude;

    if (rawPickupLat == null ||
        rawPickupLng == null ||
        !Coordinate.isValid(rawPickupLat, rawPickupLng)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Acquiring your GPS location... Please ensure location permissions are enabled.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ZyroTheme.errorRed,
        ),
      );
      _initGpsLocation();
      return;
    }

    final double? rawDestLat = _destLatLng?.latitude;
    final double? rawDestLng = _destLatLng?.longitude;

    if (rawDestLat == null ||
        rawDestLng == null ||
        !Coordinate.isValid(rawDestLat, rawDestLng)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a valid destination.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ZyroTheme.primaryColor,
        ),
      );
      _openLocationSelectionSheet(isPickup: false);
      return;
    }

    // PART 5 check
    final distKm = _haversineDistanceKm(rawPickupLat, rawPickupLng, rawDestLat, rawDestLng);
    if (distKm < 0.02) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please choose a different destination. Pickup and destination cannot be identical.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ZyroTheme.errorRed,
        ),
      );
      return;
    }

    if (_isRouting || _routeResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRouting
                ? 'Calculating road route and fare... Please wait.'
                : 'Road route is not available yet. Please wait a moment.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ZyroTheme.primaryColor,
        ),
      );
      if (!_isRouting) {
        await _updateRoute();
      }
      return;
    }

    final fareValue = _calculateFare(_selectedRideId);
    if (fareValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to calculate fare from the road distance. Please try again.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ZyroTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isBooking = true;
    });

    final selectedOption =
        _rideOptions.firstWhere((opt) => opt.id == _selectedRideId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookingConfirmationSheet(
        pickup: _pickupController.text,
        destination: _destinationController.text.isNotEmpty
            ? _destinationController.text
            : 'Selected Destination',
        selectedOption: selectedOption,
        routeResult: _routeResult,
        fare: fareValue,
        onConfirmed: () {
          Navigator.pop(ctx);
          setState(() {
            _isBooking = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RideMatchingScreen(
                pickupAddress: _pickupController.text.trim().isEmpty
                    ? 'Current Location (GPS)'
                    : _pickupController.text.trim(),
                destinationAddress: _destinationController.text.trim().isEmpty
                    ? 'Selected Destination'
                    : _destinationController.text.trim(),
                pickupLat: rawPickupLat,
                pickupLng: rawPickupLng,
                destLat: rawDestLat,
                destLng: rawDestLng,
                rideType: selectedOption.id,
                fare: fareValue,
                riderId: widget.user?.uid ?? 'rider_demo_1',
              ),
            ),
          );
        },
        onDismiss: () {
          setState(() {
            _isBooking = false;
          });
        },
      ),
    ).then((_) {
      if (_isBooking) {
        setState(() {
          _isBooking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final currentUser = widget.user ?? authService.currentUser;
    final displayName = currentUser?.displayName?.isNotEmpty == true
        ? currentUser!.displayName!
        : 'Rider';
    final photoUrl = currentUser?.photoURL;
    final isDark = ZyroTheme.isDarkMode(context);

    final LatLng? effectivePickup = _pickupLatLng ??
        (_currentRiderPosition != null
            ? LatLng(_currentRiderPosition!.latitude, _currentRiderPosition!.longitude)
            : null);

    final selectedOption =
        _rideOptions.firstWhere((opt) => opt.id == _selectedRideId);

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      body: Stack(
        children: [
          // 1. Full-Featured OpenStreetMap Central View
          Positioned.fill(
            child: ZyroMap(
              height: double.infinity,
              pickupLocation: effectivePickup,
              destinationLocation: _destLatLng,
              routePoints: _routePoints,
              onLocationUpdated: _onRiderLocationUpdated,
              cameraPadding: EdgeInsets.only(
                top: 90,
                bottom: _destLatLng != null || _routeResult != null ? 360 : 240,
                left: 30,
                right: 30,
              ),
              bottomControlsPadding:
                  _destLatLng != null || _routeResult != null ? 370 : 250,
              onMapTap: _handleMapTap,
            ),
          ),

          // 2. Floating Top Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: ZyroTheme.cardBg(context).withValues(alpha: isDark ? 0.92 : 0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ZyroTheme.borderColor(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand & Greeting
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: ZyroTheme.brandGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.electric_scooter_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'ZYRO',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 15,
                                      color: ZyroTheme.primaryColor,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: ZyroTheme.accentYellow.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '<120s',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFD48B00),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${_getGreeting()}, $displayName',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: ZyroTheme.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Profile Avatar
                      InkWell(
                        onTap: widget.onNavigateToProfile,
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: ZyroTheme.primarySurfaceAdaptive(context),
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? Text(
                                  displayName.substring(0, 1).toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: ZyroTheme.primaryColor,
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Bottom Ride Booking Drawer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: ZyroTheme.cardBg(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: ZyroTheme.borderColor(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pickup & Destination Inputs Box
                    Container(
                      decoration: BoxDecoration(
                        color: ZyroTheme.isDarkMode(context)
                            ? ZyroTheme.surfaceDarkElevated
                            : ZyroTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ZyroTheme.borderColor(context)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pickup Row (Selectable options bottom sheet)
                          InkWell(
                            onTap: () => _openLocationSelectionSheet(isPickup: true),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: ZyroTheme.successGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _pickupController.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: ZyroTheme.textPrimary(context),
                                    ),
                                  ),
                                ),
                                if (_isLocating)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(ZyroTheme.primaryColor),
                                    ),
                                  )
                                else ...[
                                  if (_isManualPickup && _currentRiderPosition != null)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.my_location_rounded,
                                        size: 16,
                                        color: ZyroTheme.primaryColor,
                                      ),
                                      tooltip: 'Reset to live device GPS',
                                      onPressed: () {
                                        setState(() {
                                          _isManualPickup = false;
                                          _pickupLatLng = LatLng(
                                            _currentRiderPosition!.latitude,
                                            _currentRiderPosition!.longitude,
                                          );
                                        });
                                        _resolvePickupAddress(
                                          _currentRiderPosition!.latitude,
                                          _currentRiderPosition!.longitude,
                                        );
                                        if (_destLatLng != null) {
                                          _updateRoute();
                                        }
                                      },
                                    ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7).withValues(alpha: isDark ? 0.2 : 1.0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'SELECT',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Divider(height: 14, color: ZyroTheme.borderColor(context)),

                          // Destination Row (Selectable options bottom sheet)
                          InkWell(
                            onTap: () => _openLocationSelectionSheet(isPickup: false),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 16, color: ZyroTheme.primaryColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _destinationController.text.isNotEmpty
                                        ? _destinationController.text
                                        : 'Where are you going? (Choose destination)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: _destinationController.text.isNotEmpty
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _destinationController.text.isNotEmpty
                                          ? ZyroTheme.textPrimary(context)
                                          : ZyroTheme.textSecondary(context),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ZyroTheme.primarySurfaceAdaptive(context),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'CHOOSE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: ZyroTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quick Saved Places Chips (Direct 1-tap destination)
                    if (_destLatLng == null && currentUser != null) ...[
                      StreamBuilder<List<SavedPlaceModel>>(
                        stream: _savedPlacesService.watchSavedPlaces(currentUser.uid),
                        builder: (context, savedSnap) {
                          final savedList = savedSnap.data ?? [];
                          if (savedList.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: savedList.map((place) {
                                    IconData placeIcon = Icons.location_on_rounded;
                                    if (place.tag == 'home') {
                                      placeIcon = Icons.home_rounded;
                                    } else if (place.tag == 'work') {
                                      placeIcon = Icons.work_rounded;
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ActionChip(
                                        avatar: Icon(placeIcon,
                                            size: 14, color: ZyroTheme.primaryColor),
                                        label: Text(
                                          place.title,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: ZyroTheme.textPrimary(context),
                                          ),
                                        ),
                                        backgroundColor: ZyroTheme.isDarkMode(context)
                                            ? ZyroTheme.surfaceDarkElevated
                                            : ZyroTheme.backgroundLight,
                                        side: BorderSide(color: ZyroTheme.borderColor(context)),
                                        onPressed: () => _selectSavedPlace(place),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],

                    // Route Summary Banner
                    if (_routeResult != null || _isRouting) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4).withValues(alpha: isDark ? 0.12 : 1.0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFBBF7D0).withValues(alpha: isDark ? 0.3 : 1.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.alt_route_rounded,
                                    color: Color(0xFF16A34A), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  _isRouting
                                      ? 'Calculating road route...'
                                      : 'Road Route: ${_routeResult!.formattedDistance}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                            if (_routeResult != null && !_isRouting)
                              Text(
                                'ETA ~${_routeResult!.formattedDuration}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Ride Option Selector Horizontal Carousel
                    Row(
                      children: _rideOptions.map((option) {
                        final isSelected = option.id == _selectedRideId;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRideId = option.id;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? ZyroTheme.primarySurfaceAdaptive(context)
                                    : (isDark ? ZyroTheme.surfaceDarkElevated : ZyroTheme.backgroundLight),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? ZyroTheme.primaryColor
                                      : ZyroTheme.borderColor(context),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    option.icon,
                                    color: isSelected
                                        ? ZyroTheme.primaryColor
                                        : ZyroTheme.textSecondary(context),
                                    size: 24,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    option.name.replaceAll('ZYRO ', ''),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? ZyroTheme.primaryColor
                                          : ZyroTheme.textPrimary(context),
                                    ),
                                  ),
                                  Text(
                                    _formattedFare(option.id),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? ZyroTheme.primaryColor
                                          : ZyroTheme.textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // Primary Book Button
                    ZyroButton(
                      text: 'Book ${selectedOption.name} • ${_formattedFare(selectedOption.id)}',
                      icon: Icons.electric_bolt_rounded,
                      isLoading: _isBooking,
                      onPressed: _handleBooking,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedLocationResult {
  final bool isUseCurrentGps;
  final String title;
  final String address;
  final LatLng? latLng;

  const _SelectedLocationResult({
    this.isUseCurrentGps = false,
    required this.title,
    required this.address,
    this.latLng,
  });
}

/// Option-Based & Live Auto-Suggesting Location Selection Sheet
class _LocationSelectionSheet extends StatefulWidget {
  final bool isPickup;
  final String uid;
  final ValidatedLocation? currentPosition;
  final GeocodingService geocodingService;
  final SavedPlacesService savedPlacesService;

  const _LocationSelectionSheet({
    required this.isPickup,
    required this.uid,
    required this.currentPosition,
    required this.geocodingService,
    required this.savedPlacesService,
  });

  @override
  State<_LocationSelectionSheet> createState() => _LocationSelectionSheetState();
}

class _LocationSelectionSheetState extends State<_LocationSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int _searchSequence = 0;
  bool _isSearching = false;
  bool _hasSearchError = false;
  String _lastSearchedQuery = '';
  List<GeocodingLocation> _searchResults = [];

  // Popular and City Hub landmarks
  final List<Map<String, dynamic>> _popularHubs = const [
    {
      'title': 'Airport Terminal Hub',
      'subtitle': 'International & Domestic Flight Terminal',
      'icon': Icons.flight_takeoff_rounded,
      'query': 'Airport Terminal',
    },
    {
      'title': 'Central Railway Station',
      'subtitle': 'Main City Train Terminal & Junction',
      'icon': Icons.train_rounded,
      'query': 'Central Railway Station',
    },
    {
      'title': 'Interstate Bus Terminal',
      'subtitle': 'Central Bus Stand & Transit Center',
      'icon': Icons.directions_bus_rounded,
      'query': 'Bus Station',
    },
    {
      'title': 'Cyber Gateway / Tech Park',
      'subtitle': 'Major IT Corridor & Enterprise Zone',
      'icon': Icons.business_rounded,
      'query': 'Tech Park',
    },
    {
      'title': 'City General Hospital',
      'subtitle': 'Emergency & Medical Center',
      'icon': Icons.local_hospital_rounded,
      'query': 'City Hospital',
    },
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    final query = value.trim();

    if (query.length < 2) {
      setState(() {
        _isSearching = false;
        _hasSearchError = false;
        _searchResults = [];
        _lastSearchedQuery = '';
      });
      return;
    }

    // 350ms debounce for responsive auto-suggestions without overwhelming the API
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final int currentSeq = ++_searchSequence;
      setState(() {
        _isSearching = true;
        _hasSearchError = false;
        _lastSearchedQuery = query;
      });

      try {
        final results = await widget.geocodingService.search(
          query,
          proximityLat: widget.currentPosition?.latitude,
          proximityLng: widget.currentPosition?.longitude,
        );

        if (!mounted || currentSeq != _searchSequence) return;

        // Filter and validate coordinates
        final validResults = results
            .where((loc) =>
                Coordinate.isValid(loc.latitude, loc.longitude) &&
                !(loc.latitude == 0.0 && loc.longitude == 0.0))
            .toList();

        setState(() {
          _isSearching = false;
          _searchResults = validResults;
        });
      } catch (e) {
        if (!mounted || currentSeq != _searchSequence) return;
        setState(() {
          _isSearching = false;
          _hasSearchError = true;
        });
      }
    });
  }

  Future<void> _selectPopularHub(Map<String, dynamic> hub) async {
    final query = hub['query'] as String;
    setState(() {
      _isSearching = true;
    });

    final results = await widget.geocodingService.search(
      query,
      proximityLat: widget.currentPosition?.latitude,
      proximityLng: widget.currentPosition?.longitude,
    );

    if (!mounted) return;
    setState(() {
      _isSearching = false;
    });

    if (results.isNotEmpty) {
      final best = results.first;
      Navigator.pop(
        context,
        _SelectedLocationResult(
          title: hub['title'] as String,
          address: best.displayName,
          latLng: LatLng(best.latitude, best.longitude),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resolve location for ${hub['title']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.isPickup ? 'Pickup Location' : 'Destination';
    final hasSearchQuery = _searchController.text.trim().length >= 2;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: ZyroTheme.borderColor(context),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header: Title & Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.isPickup ? ZyroTheme.successGreen : ZyroTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    titleText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ZyroTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                color: ZyroTheme.textSecondary(context),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Input Bar (Always visible with live onChanged auto-search)
          Container(
            decoration: BoxDecoration(
              color: ZyroTheme.isDarkMode(context)
                  ? ZyroTheme.surfaceDarkElevated
                  : ZyroTheme.backgroundLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasSearchQuery
                    ? ZyroTheme.primaryColor
                    : ZyroTheme.borderColor(context),
                width: hasSearchQuery ? 1.4 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: ZyroTheme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: ZyroTheme.textPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: widget.isPickup
                          ? 'Search pickup location...'
                          : 'Search destination...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: ZyroTheme.mutedText,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    color: ZyroTheme.mutedText,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Suggestions / Options Body
          Expanded(
            child: hasSearchQuery
                ? _buildSearchResultsBody()
                : _buildDefaultOptionsBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsBody() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(ZyroTheme.primaryColor),
            ),
            const SizedBox(height: 12),
            Text(
              'Searching locations...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: ZyroTheme.textSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasSearchError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 36, color: ZyroTheme.errorRed),
            const SizedBox(height: 10),
            Text(
              'Unable to search locations. Check your connection.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                color: ZyroTheme.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 36, color: ZyroTheme.mutedText),
            const SizedBox(height: 10),
            Text(
              'No locations found for "$_lastSearchedQuery"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: ZyroTheme.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching with a landmark, area name, or city.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: ZyroTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('MATCHING SUGGESTIONS'),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _searchResults.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: ZyroTheme.borderColor(context)),
            itemBuilder: (context, index) {
              final loc = _searchResults[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ZyroTheme.primarySurfaceAdaptive(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: ZyroTheme.primaryColor, size: 20),
                ),
                title: Text(
                  loc.shortName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: ZyroTheme.textPrimary(context),
                  ),
                ),
                subtitle: Text(
                  loc.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: ZyroTheme.textSecondary(context),
                  ),
                ),
                trailing: const Icon(Icons.north_west_rounded, size: 16, color: ZyroTheme.mutedText),
                onTap: () {
                  Navigator.pop(
                    context,
                    _SelectedLocationResult(
                      title: loc.shortName,
                      address: loc.displayName,
                      latLng: LatLng(loc.latitude, loc.longitude),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultOptionsBody() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. PRIMARY OPTION: Use Current Location (ONLY FOR PICKUP!)
        if (widget.isPickup) ...[
          _buildSectionHeader('CURRENT LOCATION'),
          const SizedBox(height: 8),
          _buildOptionCard(
            icon: Icons.my_location_rounded,
            iconColor: ZyroTheme.successGreen,
            title: 'Use Current Location',
            subtitle: widget.currentPosition != null
                ? 'GPS Accuracy: ±${widget.currentPosition!.accuracyMeters.toStringAsFixed(0)}m (High Precision)'
                : 'Acquiring real device coordinates...',
            isHighlighted: true,
            onTap: () {
              Navigator.pop(
                context,
                const _SelectedLocationResult(
                  isUseCurrentGps: true,
                  title: 'Current Location',
                  address: 'Current Location (GPS)',
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        // 2. SAVED PLACES SECTION
        if (widget.uid.isNotEmpty) ...[
          _buildSectionHeader('SAVED PLACES'),
          const SizedBox(height: 8),
          StreamBuilder<List<SavedPlaceModel>>(
            stream: widget.savedPlacesService.watchSavedPlaces(widget.uid),
            builder: (context, snapshot) {
              final savedPlaces = snapshot.data ?? [];
              if (savedPlaces.isEmpty) {
                return Container(
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
                      const Icon(Icons.bookmark_outline_rounded,
                          size: 18, color: ZyroTheme.mutedText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No saved places yet. Add Home & Work in Profile.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: ZyroTheme.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: savedPlaces.map((place) {
                  IconData placeIcon = Icons.location_on_rounded;
                  if (place.tag == 'home') {
                    placeIcon = Icons.home_rounded;
                  } else if (place.tag == 'work') {
                    placeIcon = Icons.work_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildOptionCard(
                      icon: placeIcon,
                      iconColor: ZyroTheme.primaryColor,
                      title: place.title,
                      subtitle: place.address,
                      onTap: () {
                        Navigator.pop(
                          context,
                          _SelectedLocationResult(
                            title: place.title,
                            address: place.address,
                            latLng: LatLng(place.latitude, place.longitude),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        // 3. POPULAR PLACES & CITY HUBS SECTION
        _buildSectionHeader('POPULAR DESTINATIONS & HUBS'),
        const SizedBox(height: 8),
        ..._popularHubs.map(
          (hub) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildOptionCard(
              icon: hub['icon'] as IconData,
              iconColor: const Color(0xFF2563EB),
              title: hub['title'] as String,
              subtitle: hub['subtitle'] as String,
              onTap: () => _selectPopularHub(hub),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: ZyroTheme.textSecondary(context),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isHighlighted = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isHighlighted
              ? ZyroTheme.primarySurfaceAdaptive(context)
              : (ZyroTheme.isDarkMode(context)
                  ? ZyroTheme.surfaceDarkElevated
                  : ZyroTheme.backgroundLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted ? iconColor.withValues(alpha: 0.5) : ZyroTheme.borderColor(context),
            width: isHighlighted ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: ZyroTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: ZyroTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: ZyroTheme.mutedText),
          ],
        ),
      ),
    );
  }
}

class _BookingConfirmationSheet extends StatelessWidget {
  final String pickup;
  final String destination;
  final RideOption selectedOption;
  final RouteResult? routeResult;
  final double fare;
  final VoidCallback onConfirmed;
  final VoidCallback onDismiss;

  const _BookingConfirmationSheet({
    required this.pickup,
    required this.destination,
    required this.selectedOption,
    this.routeResult,
    required this.fare,
    required this.onConfirmed,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: ZyroTheme.borderColor(context),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confirm Booking',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ZyroTheme.textPrimary(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZyroTheme.primarySurfaceAdaptive(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '<120s Dispatch',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ZyroTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ZyroTheme.isDarkMode(context)
                    ? ZyroTheme.surfaceDarkElevated
                    : ZyroTheme.backgroundLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZyroTheme.borderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(selectedOption.icon, color: selectedOption.iconColor, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedOption.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ZyroTheme.textPrimary(context),
                          ),
                        ),
                        Text(
                          routeResult != null
                              ? '${routeResult!.formattedDistance} • ~${routeResult!.formattedDuration}'
                              : 'Estimated arrival in ${selectedOption.eta}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: ZyroTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${fare.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ZyroTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ZyroButton(
              text: 'Confirm & Match Driver',
              icon: Icons.check_circle_rounded,
              onPressed: onConfirmed,
            ),
          ],
        ),
      ),
    );
  }
}

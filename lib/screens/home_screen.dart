import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/coordinate.dart';
import '../models/validated_location.dart';
import '../services/auth_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
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
  final GeocodingService _geocodingService = NominatimGeocodingService();
  final RoutingService _routingService = OsrmRoutingService();

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

  final List<Map<String, String>> _recentPlaces = const [
    {
      'title': 'Work Office (Ecospace)',
      'address': 'RMZ Ecospace, Outer Ring Rd, Bellandur, Bengaluru',
      'distance': '6.4 km',
    },
    {
      'title': 'Indiranagar 100ft Road',
      'address': '100 Feet Road, Indiranagar, Bengaluru',
      'distance': '3.8 km',
    },
    {
      'title': 'Koramangala 5th Block',
      'address': 'Koramangala 5th Block, Bengaluru',
      'distance': '4.2 km',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initGpsLocation();
  }

  Future<void> _initGpsLocation() async {
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

  /// Calculates the fare from the actual OSRM road distance.
  /// Before a destination/route is available, this returns null so the UI
  /// shows ₹-- instead of a misleading fixed fare.
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

    // Round to the nearest rupee for a clean customer-facing fare.
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

      // Only auto-assign pickup coordinate on first acquisition or if not manually set
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

    debugPrint(
      'ROUTE START:\nlat = ${origin.latitude}\nlng = ${origin.longitude}',
    );
    debugPrint(
      'ROUTE END:\nlat = ${_destLatLng!.latitude}\nlng = ${_destLatLng!.longitude}',
    );

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

  Future<void> _openPickupSearchSheet() => _openLocationSearchSheet(isPickup: true);
  Future<void> _openDestinationSearchSheet() => _openLocationSearchSheet(isPickup: false);

  Future<void> _openLocationSearchSheet({required bool isPickup}) async {
    final searchController = TextEditingController(
      text: isPickup ? _pickupController.text : _destinationController.text,
    );
    List<GeocodingLocation> searchResults = [];
    bool isSearching = false;
    String? searchError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> performSearch() async {
              final query = searchController.text.trim();
              if (query.length < 2) return;

              setModalState(() {
                isSearching = true;
                searchError = null;
              });

              final results = await _geocodingService.search(
                query,
                proximityLat: isPickup
                    ? _currentRiderPosition?.latitude
                    : (_pickupLatLng?.latitude ?? _currentRiderPosition?.latitude),
                proximityLng: isPickup
                    ? _currentRiderPosition?.longitude
                    : (_pickupLatLng?.longitude ?? _currentRiderPosition?.longitude),
              );

              if (!context.mounted) return;

              setModalState(() {
                isSearching = false;
                searchResults = results;
                if (results.isEmpty) {
                  searchError = 'No locations found for "$query". Please refine your search.';
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
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
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: ZyroTheme.borderLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isPickup ? 'Set Pickup Location' : 'Search Destination',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ZyroTheme.darkCharcoal,
                        ),
                      ),
                      if (isPickup && _currentRiderPosition != null)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context, 'USE_GPS');
                          },
                          icon: const Icon(
                            Icons.my_location_rounded,
                            size: 15,
                            color: ZyroTheme.successGreen,
                          ),
                          label: Text(
                            'Use Device GPS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ZyroTheme.successGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search Bar Input
                  Container(
                    decoration: BoxDecoration(
                      color: ZyroTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (isPickup ? ZyroTheme.successGreen : ZyroTheme.primaryColor).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          isPickup ? Icons.my_location_rounded : Icons.search_rounded,
                          color: isPickup ? ZyroTheme.successGreen : ZyroTheme.primaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => performSearch(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ZyroTheme.darkCharcoal,
                            ),
                            decoration: InputDecoration(
                              hintText: isPickup
                                  ? 'Enter pickup address or landmark...'
                                  : 'Enter landmark, street, or city...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                        if (searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: ZyroTheme.mutedText),
                            onPressed: () {
                              searchController.clear();
                              setModalState(() {
                                searchResults = [];
                                searchError = null;
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded,
                              size: 20, color: ZyroTheme.primaryColor),
                          onPressed: performSearch,
                        ),
                      ],
                    ),
                  ),

                  if (isSearching) ...[
                    const SizedBox(height: 24),
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(ZyroTheme.primaryColor),
                      ),
                    ),
                  ],

                  if (searchError != null && !isSearching) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ZyroTheme.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: ZyroTheme.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              searchError!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: ZyroTheme.darkCharcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Results List
                  Expanded(
                    child: searchResults.isEmpty && !isSearching
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPickup ? Icons.location_pin : Icons.search_rounded,
                                  size: 40,
                                  color: ZyroTheme.mutedText.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isPickup
                                      ? 'Search any pickup location, street, or landmark'
                                      : 'Type a destination or landmark name and press Search',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: ZyroTheme.mutedText,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(top: 12),
                            itemCount: searchResults.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1, color: ZyroTheme.borderLight),
                            itemBuilder: (context, index) {
                              final loc = searchResults[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isPickup
                                        ? const Color(0xFFDCFCE7)
                                        : ZyroTheme.primarySurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isPickup ? Icons.my_location_rounded : Icons.location_on_rounded,
                                    color: isPickup ? ZyroTheme.successGreen : ZyroTheme.primaryColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  loc.shortName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ZyroTheme.darkCharcoal,
                                  ),
                                ),
                                subtitle: Text(
                                  loc.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: ZyroTheme.mutedText,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context, loc);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((selected) {
      if (selected == 'USE_GPS' && mounted) {
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
        if (_destLatLng != null) {
          _updateRoute();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reset to live device GPS location',
              style: GoogleFonts.plusJakartaSans(),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (selected is GeocodingLocation && mounted) {
        if (isPickup) {
          setState(() {
            _isManualPickup = true;
            _pickupController.text = selected.displayName;
            _pickupLatLng = LatLng(selected.latitude, selected.longitude);
          });
          if (_destLatLng != null) {
            _updateRoute();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pickup set to ${selected.shortName}',
                style: GoogleFonts.plusJakartaSans(),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          setState(() {
            _destinationController.text = selected.displayName;
            _destLatLng = LatLng(selected.latitude, selected.longitude);
          });
          _updateRoute();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Destination set to ${selected.shortName}',
                style: GoogleFonts.plusJakartaSans(),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  Future<void> _handleMapTap(LatLng point) async {
    if (!Coordinate.isValid(point.latitude, point.longitude)) return;

    if (_destLatLng == null) {
      // Direct set destination
      setState(() {
        _destLatLng = point;
        _destinationController.text = 'Resolving address...';
      });
      _updateRoute();
      try {
        final address = await _geocodingService.reverseGeocode(point.latitude, point.longitude);
        if (mounted) {
          setState(() {
            _destinationController.text = address ??
                'Pinned Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
          });
          _updateRoute();
        }
      } catch (_) {}
    } else {
      // Prompt user whether to set point as Pickup or Destination
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZyroTheme.borderLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Set Tapped Map Location',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ZyroTheme.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.my_location_rounded, color: ZyroTheme.successGreen, size: 20),
                  ),
                  title: Text(
                    'Set as Pickup Location',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ZyroTheme.mutedText),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _isManualPickup = true;
                      _pickupLatLng = point;
                      _pickupController.text = 'Resolving pickup address...';
                    });
                    _resolvePickupAddress(point.latitude, point.longitude);
                    _updateRoute();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ZyroTheme.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: ZyroTheme.primaryColor, size: 20),
                  ),
                  title: Text(
                    'Set as Destination',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ZyroTheme.mutedText),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _destLatLng = point;
                      _destinationController.text = 'Resolving destination address...';
                    });
                    try {
                      final address = await _geocodingService.reverseGeocode(point.latitude, point.longitude);
                      if (mounted) {
                        setState(() {
                          _destinationController.text = address ??
                              'Pinned Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
                        });
                        _updateRoute();
                      }
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _selectRecentPlace(Map<String, String> place) async {
    final address = place['address'] ?? '';
    _destinationController.text = address;

    final results = await _geocodingService.search(
      address,
      proximityLat: _pickupLatLng?.latitude ?? _currentRiderPosition?.latitude,
      proximityLng: _pickupLatLng?.longitude ?? _currentRiderPosition?.longitude,
    );

    if (results.isNotEmpty && mounted) {
      setState(() {
        _destLatLng = LatLng(results.first.latitude, results.first.longitude);
      });
      _updateRoute();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Set destination to ${place['title']}',
              style: GoogleFonts.plusJakartaSans(),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not find coordinates for "${place['title']}". Please search manually.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ZyroTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _handleBooking() async {
    if (_destLatLng == null && _destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select or search a destination first.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ZyroTheme.primaryColor,
        ),
      );
      _openDestinationSearchSheet();
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
            'Please select a valid destination on the map.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ZyroTheme.primaryColor,
        ),
      );
      _openDestinationSearchSheet();
      return;
    }

    // Fare depends on the actual OSRM road distance, so do not allow
    // confirmation until the route has been calculated successfully.
    if (_isRouting || _routeResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRouting
                ? 'Calculating the road route and fare... Please wait.'
                : 'Road route is not available yet. Please wait a moment and try again.',
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

    final LatLng? effectivePickup = _pickupLatLng ??
        (_currentRiderPosition != null
            ? LatLng(_currentRiderPosition!.latitude, _currentRiderPosition!.longitude)
            : null);

    final selectedOption =
        _rideOptions.firstWhere((opt) => opt.id == _selectedRideId);

    return Scaffold(
      backgroundColor: ZyroTheme.backgroundLight,
      body: Stack(
        children: [
          // 1. Full-Featured Main Map Area (Rapido/Uber style centerpiece)
          Positioned.fill(
            child: ZyroMap(
              pickupLocation: effectivePickup,
              destinationLocation: _destLatLng,
              routePoints: _routePoints,
              onLocationUpdated: _onRiderLocationUpdated,
              showZoomControls: true,
              showRecenterButton: true,
              cameraPadding: EdgeInsets.only(
                top: 100,
                bottom: _destLatLng != null || _routeResult != null ? 390 : 250,
                left: 36,
                right: 36,
              ),
              bottomControlsPadding:
                  _destLatLng != null || _routeResult != null ? 390 : 250,
              onMapTap: _handleMapTap,
            ),
          ),

          // 2. Floating Top Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ZyroTheme.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
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
                                  color: ZyroTheme.darkCharcoal,
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
                          backgroundColor: ZyroTheme.primarySurface,
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
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

          // 3. Bottom Ride Booking Sheet / Panel (Rapido/Uber style interactive drawer)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
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
                          color: ZyroTheme.borderLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pickup & Destination Inputs Box
                    Container(
                      decoration: BoxDecoration(
                        color: ZyroTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ZyroTheme.borderLight),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pickup Row (Interactive)
                          InkWell(
                            onTap: _openPickupSearchSheet,
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
                                      color: ZyroTheme.darkCharcoal,
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
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'CHANGE',
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
                          const Divider(height: 14, color: ZyroTheme.borderLight),

                          // Destination Row (Tap to Search)
                          InkWell(
                            onTap: _openDestinationSearchSheet,
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 16, color: ZyroTheme.primaryColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _destinationController.text.isNotEmpty
                                        ? _destinationController.text
                                        : 'Where are you going? (Tap to search)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: _destinationController.text.isNotEmpty
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _destinationController.text.isNotEmpty
                                          ? ZyroTheme.darkCharcoal
                                          : ZyroTheme.mutedText,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ZyroTheme.primarySurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'SEARCH',
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

                    // Quick Recent Places Chips (when destination is not yet set)
                    if (_destLatLng == null) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _recentPlaces.map((place) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                avatar: const Icon(Icons.history_rounded,
                                    size: 14, color: ZyroTheme.primaryColor),
                                label: Text(
                                  place['title']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: ZyroTheme.darkCharcoal,
                                  ),
                                ),
                                backgroundColor: ZyroTheme.backgroundLight,
                                side: const BorderSide(color: ZyroTheme.borderLight),
                                onPressed: () => _selectRecentPlace(place),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    // If route is calculated, show route summary banner
                    if (_routeResult != null || _isRouting) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
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

                    // Ride Option Selector Horizontal Carousel / List
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
                                    ? ZyroTheme.primarySurface
                                    : ZyroTheme.backgroundLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? ZyroTheme.primaryColor
                                      : ZyroTheme.borderLight,
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
                                        : ZyroTheme.mutedText,
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
                                          : ZyroTheme.darkCharcoal,
                                    ),
                                  ),
                                  Text(
                                    _formattedFare(option.id),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? ZyroTheme.primaryColor
                                          : ZyroTheme.darkCharcoal,
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
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
                  color: ZyroTheme.borderLight,
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
                    color: ZyroTheme.darkCharcoal,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZyroTheme.primarySurface,
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
                color: ZyroTheme.backgroundLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZyroTheme.borderLight),
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
                          ),
                        ),
                        Text(
                          routeResult != null
                              ? '${routeResult!.formattedDistance} • ~${routeResult!.formattedDuration}'
                              : 'Estimated arrival in ${selectedOption.eta}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: ZyroTheme.mutedText,
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

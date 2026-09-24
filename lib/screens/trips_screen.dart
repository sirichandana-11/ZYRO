import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ride_model.dart';
import '../services/auth_service.dart';
import '../services/ride_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/trip_card.dart';
import 'saved_places_screen.dart';

class TripsScreen extends StatefulWidget {
  final User? user;
  final VoidCallback? onBookNewRide;

  const TripsScreen({
    super.key,
    this.user,
    this.onBookNewRide,
  });

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final RideService _rideService = RideService();
  final AuthService _authService = AuthService();

  TripModel _mapRideToTripModel(RideModel ride) {
    final dateStr = ride.requestedAt != null
        ? '${ride.requestedAt!.day.toString().padLeft(2, '0')}/${ride.requestedAt!.month.toString().padLeft(2, '0')}/${ride.requestedAt!.year}'
        : 'Recent';
    final timeStr = ride.requestedAt != null
        ? '${ride.requestedAt!.hour.toString().padLeft(2, '0')}:${ride.requestedAt!.minute.toString().padLeft(2, '0')}'
        : '';

    IconData vehicleIcon;
    String vehicleName;
    switch (ride.rideType.toLowerCase()) {
      case 'auto':
        vehicleIcon = Icons.electric_rickshaw_rounded;
        vehicleName = 'ZYRO Auto';
        break;
      case 'cab':
        vehicleIcon = Icons.directions_car_rounded;
        vehicleName = 'ZYRO Prime Cab';
        break;
      default:
        vehicleIcon = Icons.two_wheeler_rounded;
        vehicleName = 'ZYRO Bike';
    }

    TripStatus status;
    if (ride.status == RideStatus.completed) {
      status = TripStatus.completed;
    } else if (ride.status == RideStatus.cancelled || ride.status == RideStatus.noDriver) {
      status = TripStatus.cancelled;
    } else {
      status = TripStatus.active;
    }

    return TripModel(
      id: ride.id,
      date: dateStr,
      time: timeStr,
      pickup: ride.pickupAddress?.isNotEmpty == true
          ? ride.pickupAddress!
          : 'Lat: ${ride.pickupLatitude.toStringAsFixed(4)}, Lng: ${ride.pickupLongitude.toStringAsFixed(4)}',
      destination: ride.destinationAddress?.isNotEmpty == true
          ? ride.destinationAddress!
          : 'Lat: ${ride.destinationLatitude.toStringAsFixed(4)}, Lng: ${ride.destinationLongitude.toStringAsFixed(4)}',
      vehicleType: vehicleName,
      vehicleIcon: vehicleIcon,
      fare: '₹${ride.fare.toStringAsFixed(0)}',
      status: status,
      driverName: ride.driverId != null ? 'ZYRO Driver' : 'Searching for Driver',
      driverRating: '4.9',
      vehicleNumber: 'ZYRO-EV',
      eta: ride.status == RideStatus.searching ? '120s Allocation' : 'Assigned',
    );
  }

  void _showTrackRideSheet(TripModel trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LiveRideTrackingSheet(
        trip: trip,
        onCancelTrip: () async {
          Navigator.pop(ctx);
          await _rideService.cancelRide(trip.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Ride ${trip.id} has been cancelled.',
                  style: GoogleFonts.plusJakartaSans(),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.user ?? _authService.currentUser;
    final userId = currentUser?.uid ?? '';

    if (userId.isEmpty) {
      return Scaffold(
        backgroundColor: ZyroTheme.scaffoldBg(context),
        appBar: AppBar(
          title: Text(
            'Activity & Trips',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ZyroTheme.textPrimary(context),
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Please log in to view your trips history.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: ZyroTheme.textSecondary(context),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Activity & Trips',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.textPrimary(context),
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<RideModel>>(
          stream: _rideService.watchRidesForRider(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ZyroTheme.primaryColor),
                ),
              );
            }

            final rides = snapshot.data ?? [];
            final activeRides = rides
                .where((r) =>
                    r.status == RideStatus.searching ||
                    r.status == RideStatus.driverAssigned ||
                    r.status == RideStatus.driverArriving ||
                    r.status == RideStatus.driverArrived ||
                    r.status == RideStatus.rideStarted)
                .toList();

            final pastRides = rides
                .where((r) =>
                    r.status == RideStatus.completed ||
                    r.status == RideStatus.cancelled ||
                    r.status == RideStatus.noDriver)
                .toList();

            final activeTrips = activeRides.map(_mapRideToTripModel).toList();
            final pastTrips = pastRides.map(_mapRideToTripModel).toList();

            final hasActiveTrip = activeTrips.isNotEmpty;
            final hasHistory = pastTrips.isNotEmpty;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. ACTIVE TRIPS SECTION (if any)
                if (hasActiveTrip) ...[
                  _buildSectionHeader('ACTIVE RIDE', Icons.radar_rounded, const Color(0xFF16A34A)),
                  const SizedBox(height: 10),
                  ...activeTrips.map(
                    (trip) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ActiveTripCard(
                        trip: trip,
                        onTrackRide: () => _showTrackRideSheet(trip),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. HERO RIDE PROMO BANNER (Always present & engaging)
                _buildHeroPromoBanner(context),

                const SizedBox(height: 22),

                // 3. QUICK ACTIONS SHORTCUTS
                _buildSectionHeader('QUICK SHORTCUTS', Icons.bolt_rounded, ZyroTheme.primaryColor),
                const SizedBox(height: 10),
                _buildQuickActionsRow(context),

                const SizedBox(height: 22),

                // 4. PAST RIDES / RECENT ACTIVITY
                if (hasHistory) ...[
                  _buildSectionHeader('RECENT RIDES', Icons.history_rounded, ZyroTheme.mutedText),
                  const SizedBox(height: 10),
                  ...pastTrips.map(
                    (trip) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TripHistoryCard(
                        trip: trip,
                        onTap: () => _showTrackRideSheet(trip),
                      ),
                    ),
                  ),
                ] else ...[
                  // 5. WHY CHOOSE ZYRO - VALUE TILES (Fills empty state attractively)
                  _buildSectionHeader('WHY CHOOSE ZYRO', Icons.verified_rounded, ZyroTheme.accentYellow),
                  const SizedBox(height: 10),
                  _buildFeatureHighlights(context),
                ],

                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.textSecondary(context),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroPromoBanner(BuildContext context) {
    final isDark = ZyroTheme.isDarkMode(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF251A18), Color(0xFF1E2228)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : ZyroTheme.brandGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF3E2D28) : Colors.transparent,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: ZyroTheme.primaryColor.withValues(alpha: isDark ? 0.25 : 0.35),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⚡ <120s ALLOCATION',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your ride, your way.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Safe • Fast • Reliable Mobility',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.electric_scooter_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: widget.onBookNewRide,
            icon: const Icon(Icons.arrow_forward_rounded, color: ZyroTheme.primaryColor, size: 18),
            label: Text(
              'Book a Ride Now',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ZyroTheme.primaryColor,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: ZyroTheme.primaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(
            context: context,
            icon: Icons.my_location_rounded,
            title: 'Ride Now',
            subtitle: 'Current GPS',
            onTap: widget.onBookNewRide,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionTile(
            context: context,
            icon: Icons.bookmark_border_rounded,
            title: 'Saved Places',
            subtitle: 'Home & Work',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SavedPlacesScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ZyroTheme.cardBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ZyroTheme.borderColor(context)),
          boxShadow: ZyroTheme.isDarkMode(context)
              ? ZyroTheme.softCardShadowDark
              : ZyroTheme.softCardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ZyroTheme.primarySurfaceAdaptive(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: ZyroTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ZyroTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: ZyroTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureHighlights(BuildContext context) {
    return Column(
      children: [
        _buildFeatureItem(
          context: context,
          icon: Icons.speed_rounded,
          iconColor: ZyroTheme.primaryColor,
          title: 'High-Speed 120s Dispatch',
          description:
              'Dynamic radius expansion matches nearby verified drivers in seconds.',
        ),
        const SizedBox(height: 10),
        _buildFeatureItem(
          context: context,
          icon: Icons.shield_rounded,
          iconColor: const Color(0xFF16A34A),
          title: 'Verified Drivers & SOS Safety',
          description:
              'End-to-end trip verification, live OTP start, and 24/7 helpline.',
        ),
        const SizedBox(height: 10),
        _buildFeatureItem(
          context: context,
          icon: Icons.price_check_rounded,
          iconColor: const Color(0xFF2563EB),
          title: 'Transparent Upfront Pricing',
          description:
              'Distance-based fair calculation with zero hidden surge spikes.',
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZyroTheme.borderColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
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
                  description,
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
    );
  }
}

class _LiveRideTrackingSheet extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onCancelTrip;

  const _LiveRideTrackingSheet({
    required this.trip,
    required this.onCancelTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ZyroTheme.borderColor(context),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ride Details',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ZyroTheme.textPrimary(context),
                ),
              ),
              Text(
                trip.fare,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ZyroTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.trip_origin_rounded, color: ZyroTheme.successGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.pickup,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: ZyroTheme.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: ZyroTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.destination,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: ZyroTheme.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (trip.status == TripStatus.active)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCancelTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZyroTheme.errorRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Cancel Ride',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

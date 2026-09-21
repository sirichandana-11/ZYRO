import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/zyro_theme.dart';
import '../widgets/trip_card.dart';

class TripsScreen extends StatefulWidget {
  final VoidCallback? onBookNewRide;

  const TripsScreen({
    super.key,
    this.onBookNewRide,
  });

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  // Simulated active trip (can be toggled or completed in demo)
  TripModel? _activeTrip = const TripModel(
    id: 'TRIP-LIVE-9021',
    date: 'Today',
    time: 'Just now',
    pickup: 'Indiranagar 100ft Rd, Bengaluru',
    destination: 'Koramangala 5th Block, Bengaluru',
    vehicleType: 'ZYRO Bike',
    vehicleIcon: Icons.two_wheeler_rounded,
    fare: '₹49',
    status: TripStatus.active,
    driverName: 'Rahul Sharma',
    driverRating: '4.9',
    vehicleNumber: 'KA 05 EV 2024 (Electric)',
    eta: 'Arriving in 2 mins',
  );

  final List<TripModel> _pastTrips = const [
    TripModel(
      id: 'TRIP-8472',
      date: 'Yesterday',
      time: '06:45 PM',
      pickup: 'RMZ Ecospace, Outer Ring Rd',
      destination: 'Indiranagar 100ft Rd, Bengaluru',
      vehicleType: 'ZYRO Auto',
      vehicleIcon: Icons.electric_rickshaw_rounded,
      fare: '₹84',
      status: TripStatus.completed,
    ),
    TripModel(
      id: 'TRIP-7291',
      date: '01 Sep 2026',
      time: '09:15 AM',
      pickup: 'Koramangala 5th Block',
      destination: 'Kempegowda Int. Airport (T1)',
      vehicleType: 'ZYRO Prime Cab',
      vehicleIcon: Icons.directions_car_rounded,
      fare: '₹620',
      status: TripStatus.completed,
    ),
    TripModel(
      id: 'TRIP-6110',
      date: '28 Aug 2026',
      time: '11:30 PM',
      pickup: 'MG Road Metro Station',
      destination: 'Indiranagar 12th Main',
      vehicleType: 'ZYRO Bike',
      vehicleIcon: Icons.two_wheeler_rounded,
      fare: '₹45',
      status: TripStatus.completed,
    ),
    TripModel(
      id: 'TRIP-5028',
      date: '24 Aug 2026',
      time: '02:10 PM',
      pickup: 'Phoenix Marketcity, Whitefield',
      destination: 'HSR Layout Sector 2',
      vehicleType: 'ZYRO Auto',
      vehicleIcon: Icons.electric_rickshaw_rounded,
      fare: '₹140',
      status: TripStatus.cancelled,
    ),
  ];

  void _showTrackRideSheet(TripModel trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LiveRideTrackingSheet(
        trip: trip,
        onCancelTrip: () {
          Navigator.pop(ctx);
          setState(() {
            _activeTrip = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Trip has been cancelled.',
                style: GoogleFonts.plusJakartaSans(),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveTrip = _activeTrip != null;
    final hasHistory = _pastTrips.isNotEmpty;

    return Scaffold(
      backgroundColor: ZyroTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Trips',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.darkCharcoal,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ZyroTheme.darkCharcoal),
            tooltip: 'Refresh Trips',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Trips up to date.',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. CURRENT TRIP SECTION
              if (hasActiveTrip) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Trip',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ZyroTheme.darkCharcoal,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ZyroTheme.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Live Ride',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ZyroTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ActiveTripCard(
                  trip: _activeTrip!,
                  onTrackRide: () => _showTrackRideSheet(_activeTrip!),
                ),
                const SizedBox(height: 24),
              ],

              // 2. TRIP HISTORY SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trip History',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ZyroTheme.darkCharcoal,
                    ),
                  ),
                  Text(
                    '${_pastTrips.length} Rides',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ZyroTheme.mutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (!hasHistory && !hasActiveTrip) ...[
                // Empty State
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ZyroTheme.borderLight),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: ZyroTheme.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          size: 32,
                          color: ZyroTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No trips yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: ZyroTheme.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your ZYRO trips will appear here.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          color: ZyroTheme.mutedText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Trip Cards List
                ..._pastTrips.map(
                  (trip) => TripHistoryCard(
                    trip: trip,
                    onTap: () {
                      _showTripDetailSheet(context, trip);
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showTripDetailSheet(BuildContext context, TripModel trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
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
                  width: 40,
                  height: 4,
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
                    'Trip Summary',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ZyroTheme.darkCharcoal,
                    ),
                  ),
                  Text(
                    trip.fare,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ZyroTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${trip.date} at ${trip.time} • ${trip.vehicleType}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: ZyroTheme.mutedText,
                ),
              ),
              const Divider(height: 24, color: ZyroTheme.borderLight),
              _DetailItem(title: 'Pickup Location', value: trip.pickup),
              const SizedBox(height: 10),
              _DetailItem(title: 'Drop Location', value: trip.destination),
              const SizedBox(height: 10),
              _DetailItem(
                title: 'Status',
                value: trip.status == TripStatus.completed ? 'Completed' : 'Cancelled',
                valueColor: trip.status == TripStatus.completed
                    ? ZyroTheme.successGreen
                    : ZyroTheme.errorRed,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('Download Invoice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ZyroTheme.darkCharcoal,
                    side: const BorderSide(color: ZyroTheme.borderLight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const _DetailItem({
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: ZyroTheme.mutedText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? ZyroTheme.darkCharcoal,
          ),
        ),
      ],
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ZyroTheme.borderLight,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Pulse Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Ride Tracking',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ZyroTheme.darkCharcoal,
                      ),
                    ),
                    Text(
                      'Driver en route to your pickup',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: ZyroTheme.mutedText,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ZyroTheme.successGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '2 mins away',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ZyroTheme.successGreen,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Driver Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ZyroTheme.backgroundLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZyroTheme.borderLight),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ZyroTheme.primarySurface,
                    child: const Icon(Icons.person_pin_rounded,
                        color: ZyroTheme.primaryColor, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.driverName ?? 'Rahul Sharma',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ZyroTheme.darkCharcoal,
                          ),
                        ),
                        Text(
                          trip.vehicleNumber ?? 'KA 05 EV 2024',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: ZyroTheme.mutedText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.phone_rounded,
                        color: ZyroTheme.successGreen),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancelTrip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZyroTheme.errorRed,
                      side: const BorderSide(color: ZyroTheme.errorRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel Ride'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZyroTheme.primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Keep Open',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

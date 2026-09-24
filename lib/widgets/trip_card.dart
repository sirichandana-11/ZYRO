import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/zyro_theme.dart';

enum TripStatus {
  active,
  completed,
  cancelled,
}

class TripModel {
  final String id;
  final String date;
  final String time;
  final String pickup;
  final String destination;
  final String vehicleType;
  final IconData vehicleIcon;
  final String fare;
  final TripStatus status;
  final String? driverName;
  final String? driverRating;
  final String? vehicleNumber;
  final String? eta;

  const TripModel({
    required this.id,
    required this.date,
    required this.time,
    required this.pickup,
    required this.destination,
    required this.vehicleType,
    required this.vehicleIcon,
    required this.fare,
    required this.status,
    this.driverName,
    this.driverRating,
    this.vehicleNumber,
    this.eta,
  });
}

class ActiveTripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTrackRide;

  const ActiveTripCard({
    super.key,
    required this.trip,
    required this.onTrackRide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ZyroTheme.primaryColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ZyroTheme.primaryColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status & ETA Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurfaceAdaptive(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ZyroTheme.primaryLight.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: ZyroTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DRIVER ASSIGNED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: ZyroTheme.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: ZyroTheme.successGreen),
                  const SizedBox(width: 4),
                  Text(
                    trip.eta ?? 'Arriving in 3 mins',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ZyroTheme.successGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Driver & Vehicle Details
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: ZyroTheme.primarySurfaceAdaptive(context),
                child: const Icon(Icons.person_pin_rounded, color: ZyroTheme.primaryColor, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          trip.driverName ?? 'Rahul Sharma',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ZyroTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: ZyroTheme.accentYellow.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFD48B00)),
                              const SizedBox(width: 2),
                              Text(
                                trip.driverRating ?? '4.9',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFD48B00),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${trip.vehicleType} • ${trip.vehicleNumber ?? "KA 05 EV 2024"}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: ZyroTheme.textSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trip.fare,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: ZyroTheme.textPrimary(context),
                ),
              ),
            ],
          ),

          Divider(height: 24, color: ZyroTheme.borderColor(context)),

          // Route Points
          _RouteRow(
            icon: Icons.radio_button_checked,
            iconColor: ZyroTheme.primaryColor,
            title: 'Pickup',
            address: trip.pickup,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: SizedBox(
              height: 12,
              child: VerticalDivider(color: ZyroTheme.borderColor(context), thickness: 1.5),
            ),
          ),
          _RouteRow(
            icon: Icons.location_on_rounded,
            iconColor: ZyroTheme.textPrimary(context),
            title: 'Drop-off',
            address: trip.destination,
          ),

          const SizedBox(height: 16),

          // Track Ride Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onTrackRide,
              icon: const Icon(Icons.navigation_rounded, size: 18, color: Colors.white),
              label: Text(
                'Track Ride Live',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZyroTheme.primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TripHistoryCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback? onTap;

  const TripHistoryCard({
    super.key,
    required this.trip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = trip.status == TripStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZyroTheme.borderColor(context)),
        boxShadow: ZyroTheme.isDarkMode(context) ? [] : ZyroTheme.softCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Date/Time + Status Badge + Fare
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ZyroTheme.primarySurfaceAdaptive(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            trip.vehicleIcon,
                            size: 18,
                            color: ZyroTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.vehicleType,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ZyroTheme.textPrimary(context),
                              ),
                            ),
                            Text(
                              '${trip.date} • ${trip.time}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: ZyroTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          trip.fare,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: ZyroTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? ZyroTheme.successGreen.withValues(alpha: 0.12)
                                : ZyroTheme.errorRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isCompleted ? 'Completed' : 'Cancelled',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCompleted
                                  ? ZyroTheme.successGreen
                                  : ZyroTheme.errorRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: ZyroTheme.borderColor(context)),
                ),

                // Pickup and Destination
                _RouteRow(
                  icon: Icons.circle,
                  iconSize: 8,
                  iconColor: ZyroTheme.primaryColor,
                  title: 'From',
                  address: trip.pickup,
                ),
                const SizedBox(height: 6),
                _RouteRow(
                  icon: Icons.location_on_rounded,
                  iconSize: 14,
                  iconColor: ZyroTheme.textPrimary(context),
                  title: 'To',
                  address: trip.destination,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String title;
  final String address;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    this.iconSize = 14,
    required this.title,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 10),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ZyroTheme.textSecondary(context),
                  ),
                ),
                TextSpan(
                  text: address,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: ZyroTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

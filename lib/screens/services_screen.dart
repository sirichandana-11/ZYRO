import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/zyro_theme.dart';
import '../widgets/service_card.dart';

class ServicesScreen extends StatelessWidget {
  final ValueChanged<String>? onSelectRideService;

  const ServicesScreen({
    super.key,
    this.onSelectRideService,
  });

  // Category 1: City Mobility Services
  final List<ServiceModel> _cityRideServices = const [
    ServiceModel(
      id: 'bike',
      title: 'ZYRO Bike',
      subtitle: 'Fastest 1-seater in traffic with sanitized helmet.',
      icon: Icons.two_wheeler_rounded,
      iconColor: ZyroTheme.primaryColor,
      isAvailable: true,
      badgeText: 'Instant',
      startingPrice: '₹25',
    ),
    ServiceModel(
      id: 'auto',
      title: 'ZYRO Auto',
      subtitle: 'Doorstep auto for up to 3 passengers.',
      icon: Icons.electric_rickshaw_rounded,
      iconColor: ZyroTheme.accentYellow,
      isAvailable: true,
      badgeText: 'Popular',
      startingPrice: '₹35',
    ),
    ServiceModel(
      id: 'cab',
      title: 'ZYRO Prime Cab',
      subtitle: 'AC Sedans with top rated verified drivers.',
      icon: Icons.directions_car_rounded,
      iconColor: Color(0xFF2A9D8F),
      isAvailable: true,
      badgeText: 'AC Comfort',
      startingPrice: '₹60',
    ),
  ];

  // Category 2: Specialized & Travel
  final List<ServiceModel> _specializedServices = const [
    ServiceModel(
      id: 'rental',
      title: 'Hourly Rentals',
      subtitle: 'Keep a ride for multiple stops and errands.',
      icon: Icons.access_time_filled_rounded,
      iconColor: Color(0xFF6366F1),
      isAvailable: true,
      badgeText: 'Flexible',
      startingPrice: '₹149/hr',
    ),
    ServiceModel(
      id: 'outstation',
      title: 'Intercity Rides',
      subtitle: 'Comfortable one-way and round trips between cities.',
      icon: Icons.alt_route_rounded,
      iconColor: Color(0xFF0EA5E9),
      isAvailable: true,
      badgeText: 'Highway',
      startingPrice: '₹499',
    ),
    ServiceModel(
      id: 'airport',
      title: 'Airport Express',
      subtitle: 'On-time terminal drop-off and flight pickups.',
      icon: Icons.flight_takeoff_rounded,
      iconColor: Color(0xFF8B5CF6),
      isAvailable: true,
      badgeText: 'Direct',
      startingPrice: '₹299',
    ),
  ];

  // Category 3: Deliveries & Logistics
  final List<ServiceModel> _deliveryServices = const [
    ServiceModel(
      id: 'parcel',
      title: 'Parcel Delivery',
      subtitle: 'Same-day instant package pickup and drop across town.',
      icon: Icons.local_shipping_rounded,
      iconColor: Color(0xFFF97316),
      isAvailable: true,
      badgeText: 'Express',
      startingPrice: '₹40',
    ),
    ServiceModel(
      id: 'freight',
      title: 'Mini Freight',
      subtitle: 'Luggage and home shifting light commercial vehicles.',
      icon: Icons.fire_truck_rounded,
      iconColor: Color(0xFF64748B),
      isAvailable: false,
      badgeText: 'Coming Soon',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = ZyroTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: ZyroTheme.cardBg(context),
        elevation: 0,
        centerTitle: false,
        title: Text(
          'All Services',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.textPrimary(context),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Promotional Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: ZyroTheme.brandGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: ZyroTheme.buttonGlowShadow,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 14, color: ZyroTheme.accentYellow),
                                const SizedBox(width: 4),
                                Text(
                                  'ZYRO MOBILITY HUB',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Your Ride, Your Choice',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'From lightning bike taxis to premium airport cabs, book verified rides in under 120 seconds.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.92),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.electric_scooter_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 1. CITY RIDES SECTION
              _buildSectionHeader(context, 'City Daily Commute', 'Instant pickup'),
              const SizedBox(height: 12),
              _buildServiceGrid(context, _cityRideServices),

              const SizedBox(height: 24),

              // 2. SPECIALIZED & TRAVEL SECTION
              _buildSectionHeader(context, 'Hourly Rentals & Outstation', 'Flexible travel'),
              const SizedBox(height: 12),
              _buildServiceGrid(context, _specializedServices),

              const SizedBox(height: 24),

              // 3. PARCEL & DELIVERIES SECTION
              _buildSectionHeader(context, 'Doorstep Delivery', 'Logistics'),
              const SizedBox(height: 12),
              _buildServiceGrid(context, _deliveryServices),

              const SizedBox(height: 28),

              // 4. WHY CHOOSE ZYRO (TRUST & SAFETY HIGHLIGHTS)
              Text(
                'Why Choose ZYRO',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: ZyroTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: ZyroTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ZyroTheme.borderColor(context)),
                  boxShadow: isDark ? [] : ZyroTheme.softCardShadow,
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildTrustRow(
                      context,
                      icon: Icons.verified_user_rounded,
                      iconColor: ZyroTheme.successGreen,
                      title: '100% Verified Drivers',
                      subtitle: 'Background-checked captains with verified vehicle documents.',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: ZyroTheme.borderColor(context)),
                    ),
                    _buildTrustRow(
                      context,
                      icon: Icons.timer_rounded,
                      iconColor: ZyroTheme.primaryColor,
                      title: '120-Second Match Guarantee',
                      subtitle: 'Authoritative auto-assignment with backup dispatch protection.',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: ZyroTheme.borderColor(context)),
                    ),
                    _buildTrustRow(
                      context,
                      icon: Icons.currency_rupee_rounded,
                      iconColor: ZyroTheme.accentYellow,
                      title: 'Transparent GPS Pricing',
                      subtitle: 'Upfront fares calculated strictly by road distance via OSRM.',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: ZyroTheme.borderColor(context)),
                    ),
                    _buildTrustRow(
                      context,
                      icon: Icons.emergency_rounded,
                      iconColor: ZyroTheme.errorRed,
                      title: '24/7 Safety SOS Helpline',
                      subtitle: 'Direct emergency assistance and real-time live ride sharing.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String badge) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.textPrimary(context),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: ZyroTheme.primarySurfaceAdaptive(context),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ZyroTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceGrid(BuildContext context, List<ServiceModel> services) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final crossAxisCount = isWide ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return ServiceCard(
              service: service,
              onTap: () {
                if (service.isAvailable) {
                  onSelectRideService?.call(service.id);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${service.title} is coming soon in your area!',
                        style: GoogleFonts.plusJakartaSans(),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTrustRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: ZyroTheme.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

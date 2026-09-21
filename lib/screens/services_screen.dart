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

  final List<ServiceModel> _rideServices = const [
    ServiceModel(
      id: 'bike',
      title: 'ZYRO Bike',
      subtitle: 'Fastest 1-seater ride in city traffic with helmet provided.',
      icon: Icons.two_wheeler_rounded,
      iconColor: ZyroTheme.primaryColor,
      isAvailable: true,
      badgeText: 'Instant',
    ),
    ServiceModel(
      id: 'auto',
      title: 'ZYRO Auto',
      subtitle: 'Pocket-friendly doorstep auto rides for up to 3 passengers.',
      icon: Icons.electric_rickshaw_rounded,
      iconColor: ZyroTheme.accentYellow,
      isAvailable: true,
      badgeText: 'Popular',
    ),
    ServiceModel(
      id: 'cab',
      title: 'ZYRO Cab',
      subtitle: 'Air-conditioned premium 4-seater cars for comfortable trips.',
      icon: Icons.directions_car_rounded,
      iconColor: Color(0xFF2A9D8F),
      isAvailable: true,
      badgeText: 'AC Comfort',
    ),
  ];

  final List<ServiceModel> _otherServices = const [
    ServiceModel(
      id: 'parcel',
      title: 'Parcel Delivery',
      subtitle: 'Same-day instant package pickup and drop across the city.',
      icon: Icons.local_shipping_rounded,
      iconColor: Color(0xFF457B9D),
      isAvailable: false,
      badgeText: 'Coming Soon',
    ),
    ServiceModel(
      id: 'grocery',
      title: 'Grocery Delivery',
      subtitle: 'Superfast 10-minute essentials and daily grocery dispatch.',
      icon: Icons.shopping_basket_rounded,
      iconColor: Color(0xFF588157),
      isAvailable: false,
      badgeText: 'Coming Soon',
    ),
    ServiceModel(
      id: 'food',
      title: 'Food Delivery',
      subtitle: 'Hot meals delivered quickly from your favorite local eateries.',
      icon: Icons.restaurant_rounded,
      iconColor: Color(0xFFE76F51),
      isAvailable: false,
      badgeText: 'Coming Soon',
    ),
    ServiceModel(
      id: 'transport',
      title: 'Mini Transport',
      subtitle: 'Luggage and house shifting light commercial vehicle rentals.',
      icon: Icons.fire_truck_rounded,
      iconColor: Color(0xFF6D597A),
      isAvailable: false,
      badgeText: 'Coming Soon',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZyroTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'All Services',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.darkCharcoal,
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
              // Promo Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: ZyroTheme.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: ZyroTheme.buttonGlowShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flash_on_rounded,
                          color: ZyroTheme.accentYellow, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seamless Multi-Modal Mobility',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Book rides in <120 seconds or explore upcoming delivery services.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // RIDE SERVICES CATEGORY
              Text(
                'Ride Services',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: ZyroTheme.darkCharcoal,
                ),
              ),
              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  final crossAxisCount = isWide ? 3 : 2;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: _rideServices.length,
                    itemBuilder: (context, index) {
                      final service = _rideServices[index];
                      return ServiceCard(
                        service: service,
                        onTap: () {
                          onSelectRideService?.call(service.id);
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 28),

              // DELIVERY / OTHER SERVICES CATEGORY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delivery & Other Services',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ZyroTheme.darkCharcoal,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9ECEF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Expansion',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ZyroTheme.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  final crossAxisCount = isWide ? 4 : 2;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: _otherServices.length,
                    itemBuilder: (context, index) {
                      final service = _otherServices[index];
                      return ServiceCard(
                        service: service,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${service.title} is coming soon in your city!',
                                style: GoogleFonts.plusJakartaSans(),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

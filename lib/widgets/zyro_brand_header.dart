import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/zyro_theme.dart';

class ZyroBrandHeaderMobile extends StatelessWidget {
  const ZyroBrandHeaderMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6D47), Color(0xFFF2542D), Color(0xFFE54118)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background subtle decorative circles
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Logo & Badge Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _ZyroLogoText(fontSize: 28, isLight: true),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt,
                            color: ZyroTheme.accentYellow,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '< 120s Dispatch',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3D Scooter Illustration Card
                Center(
                  child: Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/zyro_scooter_rider.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          color: Colors.white.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.electric_scooter_rounded,
                            size: 70,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Main Tagline
                Text(
                  'Your Ride, Without the Wait.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fast, reliable rides assigned within 120 seconds.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
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

class ZyroBrandHeaderDesktop extends StatelessWidget {
  const ZyroBrandHeaderDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6D47), Color(0xFFF2542D), Color(0xFFE54118)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Logo & Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ZyroLogoText(fontSize: 40, isLight: true),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt,
                      color: ZyroTheme.accentYellow,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Match Guarantee in 120s',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Center 3D Illustration
          Center(
            child: Container(
              height: 280,
              width: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 4,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/zyro_scooter_rider.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(
                    Icons.electric_scooter_rounded,
                    size: 120,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Tagline
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Ride,\nWithout the Wait.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Fast, reliable rides with an electric scooter or car driver assigned within 120 seconds.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ZYRO Custom Stylized Logo
class _ZyroLogoText extends StatelessWidget {
  final double fontSize;
  final bool isLight;

  const _ZyroLogoText({
    required this.fontSize,
    this.isLight = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Fast Motion Lines
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: fontSize * 0.45,
              height: fontSize * 0.09,
              decoration: BoxDecoration(
                color: isLight ? ZyroTheme.accentYellow : ZyroTheme.primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: fontSize * 0.08),
            Container(
              width: fontSize * 0.3,
              height: fontSize * 0.09,
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.white.withValues(alpha: 0.85)
                    : ZyroTheme.primaryDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Text(
          'ZYRO',
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: isLight ? Colors.white : ZyroTheme.primaryColor,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

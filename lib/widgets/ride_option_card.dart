import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/zyro_theme.dart';

class RideOption {
  final String id;
  final String name;
  final String tagline;
  final String fare;
  final String eta;
  final IconData icon;
  final Color iconColor;
  final String capacity;

  const RideOption({
    required this.id,
    required this.name,
    required this.tagline,
    required this.fare,
    required this.eta,
    required this.icon,
    required this.iconColor,
    required this.capacity,
  });
}

class RideOptionCard extends StatelessWidget {
  final RideOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const RideOptionCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? ZyroTheme.primarySurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? ZyroTheme.primaryColor : ZyroTheme.borderLight,
          width: isSelected ? 2.0 : 1.2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: ZyroTheme.primaryColor.withValues(alpha: 0.15),
                  offset: const Offset(0, 4),
                  blurRadius: 16,
                )
              ]
            : ZyroTheme.softCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Vehicle Icon Badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : option.iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected
                        ? Border.all(color: ZyroTheme.primaryLight, width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    option.icon,
                    color: option.iconColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // Name & ETA info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            option.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ZyroTheme.darkCharcoal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_rounded,
                                size: 14,
                                color: ZyroTheme.mutedText,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                option.capacity,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: ZyroTheme.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: ZyroTheme.successGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            option.eta,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ZyroTheme.successGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${option.tagline}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: ZyroTheme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Fare & Radio indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      option.fare,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? ZyroTheme.primaryColor
                            : ZyroTheme.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? ZyroTheme.primaryColor
                              : ZyroTheme.mutedText.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        color: isSelected ? ZyroTheme.primaryColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

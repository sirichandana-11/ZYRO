import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/zyro_theme.dart';

class ServiceModel {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isAvailable;
  final String? badgeText;

  const ServiceModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.isAvailable = true,
    this.badgeText,
  });
}

class ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback onTap;

  const ServiceCard({
    super.key,
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: service.isAvailable
              ? ZyroTheme.borderLight
              : ZyroTheme.borderLight.withValues(alpha: 0.6),
        ),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Icon + Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: service.iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        service.icon,
                        color: service.iconColor,
                        size: 24,
                      ),
                    ),
                    if (!service.isAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ZyroTheme.borderLight),
                        ),
                        child: Text(
                          service.badgeText ?? 'Coming Soon',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ZyroTheme.mutedText,
                          ),
                        ),
                      )
                    else if (service.badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: ZyroTheme.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          service.badgeText!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ZyroTheme.primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title & Subtitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: service.isAvailable
                            ? ZyroTheme.darkCharcoal
                            : ZyroTheme.bodyText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      service.subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: ZyroTheme.mutedText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

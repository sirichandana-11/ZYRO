import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../theme/zyro_theme.dart';
import 'legal_screen.dart';
import 'notification_settings_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final AuthService _authService = AuthService();
  final PreferencesService _prefsService = PreferencesService();

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'App Settings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.textPrimary(context),
          ),
        ),
        backgroundColor: ZyroTheme.cardBg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: ZyroTheme.textPrimary(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? Center(
              child: Text(
                'Please sign in to manage settings.',
                style: GoogleFonts.plusJakartaSans(
                  color: ZyroTheme.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : StreamBuilder<Map<String, dynamic>>(
              stream: _prefsService.watchAppPreferences(user.uid),
              builder: (context, snapshot) {
                final appPrefs = snapshot.data ?? {};
                final currentTheme = (appPrefs['themeMode'] as String? ?? 'system').toLowerCase();
                final currentUnit = (appPrefs['distanceUnit'] as String? ?? 'km').toLowerCase();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildSectionHeader('APPEARANCE & DISPLAY'),
                    const SizedBox(height: 8),
                    _buildCard(context, [
                      _buildThemeSelector(context, user.uid, currentTheme),
                      Divider(height: 1, indent: 56, endIndent: 16, color: ZyroTheme.borderColor(context)),
                      _buildUnitSelector(context, user.uid, currentUnit),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionHeader('NOTIFICATIONS'),
                    const SizedBox(height: 8),
                    _buildCard(context, [
                      _buildActionTile(
                        context: context,
                        icon: Icons.notifications_none_rounded,
                        title: 'Notification Preferences',
                        subtitle: 'Ride status alerts, discounts & alerts',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionHeader('LEGAL & PRIVACY'),
                    const SizedBox(height: 8),
                    _buildCard(context, [
                      _buildActionTile(
                        context: context,
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How ZYRO collects and safeguards your data',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(type: LegalDocumentType.privacyPolicy),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, indent: 56, endIndent: 16, color: ZyroTheme.borderColor(context)),
                      _buildActionTile(
                        context: context,
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'User agreement, rider & driver guidelines',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalScreen(type: LegalDocumentType.termsOfService),
                            ),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionHeader('ABOUT APPLICATION'),
                    const SizedBox(height: 8),
                    _buildCard(context, [
                      _buildActionTile(
                        context: context,
                        icon: Icons.info_outline_rounded,
                        title: 'About ZYRO',
                        subtitle: 'Version 1.0.0 (Production 2026.1)',
                        onTap: () => _showAboutDialog(context),
                      ),
                    ]),
                    const SizedBox(height: 30),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: ZyroTheme.mutedText,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZyroTheme.borderColor(context)),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildThemeSelector(BuildContext context, String uid, String currentTheme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ZyroTheme.primarySurfaceAdaptive(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.palette_outlined, color: ZyroTheme.primaryColor, size: 20),
      ),
      title: Text(
        'App Theme',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: ZyroTheme.textPrimary(context),
        ),
      ),
      subtitle: Text(
        currentTheme == 'dark'
            ? 'Dark Mode'
            : (currentTheme == 'light' ? 'Light Mode' : 'System Default'),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: ZyroTheme.mutedText,
        ),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentTheme,
          dropdownColor: ZyroTheme.cardBg(context),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ZyroTheme.textPrimary(context),
          ),
          items: const [
            DropdownMenuItem(value: 'system', child: Text('System')),
            DropdownMenuItem(value: 'light', child: Text('Light')),
            DropdownMenuItem(value: 'dark', child: Text('Dark')),
          ],
          onChanged: (val) {
            if (val != null) {
              _prefsService.updateAppPreference(uid, 'themeMode', val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildUnitSelector(BuildContext context, String uid, String currentUnit) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ZyroTheme.primarySurfaceAdaptive(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.straighten_rounded, color: ZyroTheme.primaryColor, size: 20),
      ),
      title: Text(
        'Distance Units',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: ZyroTheme.textPrimary(context),
        ),
      ),
      subtitle: Text(
        currentUnit == 'miles' ? 'Miles (mi)' : 'Kilometers (km)',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: ZyroTheme.mutedText,
        ),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentUnit,
          dropdownColor: ZyroTheme.cardBg(context),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ZyroTheme.textPrimary(context),
          ),
          items: const [
            DropdownMenuItem(value: 'km', child: Text('Kilometers (km)')),
            DropdownMenuItem(value: 'miles', child: Text('Miles (mi)')),
          ],
          onChanged: (val) {
            if (val != null) {
              _prefsService.updateAppPreference(uid, 'distanceUnit', val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ZyroTheme.primarySurfaceAdaptive(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: ZyroTheme.primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: ZyroTheme.textPrimary(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: ZyroTheme.mutedText,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: ZyroTheme.mutedText,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZyroTheme.cardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: ZyroTheme.brandGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.electric_scooter_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'About ZYRO',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: ZyroTheme.textPrimary(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ZYRO - Urban High-Speed Mobility',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ZyroTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Instant rider dispatching, verified drivers, transparent upfront pricing, and real-time live map tracking.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: ZyroTheme.textSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Version 1.0.0 (Build 2026.1)\n© 2026 ZYRO Inc. All rights reserved.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: ZyroTheme.mutedText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: ZyroTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

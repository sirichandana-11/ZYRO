import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../theme/zyro_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final AuthService _authService = AuthService();
  final PreferencesService _prefsService = PreferencesService();

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: ZyroTheme.scaffoldBg(context),
        appBar: AppBar(
          title: Text(
            'Notifications',
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
        body: Center(
          child: Text(
            'Please sign in to manage notifications.',
            style: GoogleFonts.plusJakartaSans(
              color: ZyroTheme.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'Notification Settings',
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
      body: StreamBuilder<Map<String, bool>>(
        stream: _prefsService.watchNotificationPreferences(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ZyroTheme.primaryColor),
              ),
            );
          }

          final prefs = snapshot.data ?? {};

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              _buildSectionHeader('RIDE STATUS ALERTS'),
              const SizedBox(height: 8),
              _buildCard(context, [
                _buildToggleTile(
                  context: context,
                  title: 'Driver Assigned',
                  subtitle: 'Alert when a driver accepts your ride request',
                  value: prefs['driverAssigned'] ?? true,
                  onChanged: (val) => _updatePreference(user.uid, prefs, 'driverAssigned', val),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: ZyroTheme.borderColor(context)),
                _buildToggleTile(
                  context: context,
                  title: 'Driver Arriving',
                  subtitle: 'Alert when driver is within 2 minutes of pickup',
                  value: prefs['driverArriving'] ?? true,
                  onChanged: (val) => _updatePreference(user.uid, prefs, 'driverArriving', val),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: ZyroTheme.borderColor(context)),
                _buildToggleTile(
                  context: context,
                  title: 'Ride Started',
                  subtitle: 'Confirmation when OTP is verified and trip begins',
                  value: prefs['rideStarted'] ?? true,
                  onChanged: (val) => _updatePreference(user.uid, prefs, 'rideStarted', val),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: ZyroTheme.borderColor(context)),
                _buildToggleTile(
                  context: context,
                  title: 'Ride Completed',
                  subtitle: 'Trip receipt summary and rating prompt',
                  value: prefs['rideCompleted'] ?? true,
                  onChanged: (val) => _updatePreference(user.uid, prefs, 'rideCompleted', val),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: ZyroTheme.borderColor(context)),
                _buildToggleTile(
                  context: context,
                  title: 'Ride Cancellations',
                  subtitle: 'Alerts if a driver or system cancels your ride',
                  value: prefs['rideCancelled'] ?? true,
                  onChanged: (val) => _updatePreference(user.uid, prefs, 'rideCancelled', val),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader('OFFERS & MARKETING'),
              const SizedBox(height: 8),
              _buildCard(context, [
                _buildToggleTile(
                  context: context,
                  title: 'Discounts & Promotions',
                  subtitle: 'Receive promotional coupon codes and festive offers',
                  value: prefs['promotions'] ?? false,
                  onChanged: (val) => _updatePreference(user.uid, prefs, 'promotions', val),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader('ACCOUNT & SECURITY'),
              const SizedBox(height: 8),
              _buildCard(context, [
                _buildToggleTile(
                  context: context,
                  title: 'Security Alerts',
                  subtitle: 'Important account activity, password reset & logins',
                  value: prefs['securityAlerts'] ?? true,
                  onChanged: (val) => _updatePreference(user.uid, prefs, 'securityAlerts', val),
                ),
              ]),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurfaceAdaptive(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ZyroTheme.primaryColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: ZyroTheme.primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Notification preferences are synced to your ZYRO account. Critical safety SOS notifications cannot be disabled.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: ZyroTheme.textPrimary(context),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updatePreference(
    String uid,
    Map<String, bool> currentPrefs,
    String key,
    bool newValue,
  ) async {
    final updated = Map<String, bool>.from(currentPrefs);
    updated[key] = newValue;
    try {
      await _prefsService.updateNotificationPreferences(uid, updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZyroTheme.errorRed,
            content: Text(
              'Failed to update notification settings: $e',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
          ),
        );
      }
    }
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

  Widget _buildToggleTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: ZyroTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: ZyroTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeTrackColor: ZyroTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

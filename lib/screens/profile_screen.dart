import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/zyro_button.dart';

class ProfileScreen extends StatelessWidget {
  final User? user;

  const ProfileScreen({
    super.key,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final currentUser = user ?? authService.currentUser;
    final displayName = currentUser?.displayName?.isNotEmpty == true
        ? currentUser!.displayName!
        : 'Siri';
    final email = currentUser?.email ?? 'siri@gmail.com';
    final photoUrl = currentUser?.photoURL;

    return Scaffold(
      backgroundColor: ZyroTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Profile',
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
              // Top Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: ZyroTheme.borderLight),
                  boxShadow: ZyroTheme.softCardShadow,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: ZyroTheme.primarySurface,
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? Text(
                              displayName.substring(0, 1).toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: ZyroTheme.primaryColor,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ZyroTheme.darkCharcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: ZyroTheme.mutedText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ZyroTheme.primarySurface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Rider Account',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ZyroTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  _showEditProfileDialog(context, displayName);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ZyroTheme.backgroundLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: ZyroTheme.borderLight),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.edit_outlined,
                                          size: 11, color: ZyroTheme.mutedText),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Edit',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: ZyroTheme.darkCharcoal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ACCOUNT SECTION
              _SectionHeader(title: 'Account'),
              const SizedBox(height: 8),
              _MenuContainer(
                items: [
                  _MenuItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                    subtitle: 'Name, phone number, email address',
                    onTap: () => _showComingSoon(context, 'Personal Information'),
                  ),
                  _MenuItem(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Saved Places',
                    subtitle: 'Home, Work, Frequent drop-offs',
                    onTap: () => _showComingSoon(context, 'Saved Places'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // PAYMENTS SECTION
              _SectionHeader(title: 'Payments & Wallet'),
              const SizedBox(height: 8),
              _MenuContainer(
                items: [
                  _MenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Payment Methods',
                    subtitle: 'UPI, Credit/Debit Cards, Cash',
                    badge: 'ZYRO Pay',
                    onTap: () => _showComingSoon(context, 'Payment Methods'),
                  ),
                  _MenuItem(
                    icon: Icons.receipt_long_outlined,
                    title: 'Payment History',
                    subtitle: 'Invoices, receipts and monthly breakdown',
                    onTap: () => _showComingSoon(context, 'Payment History'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // PREFERENCES SECTION
              _SectionHeader(title: 'Preferences'),
              const SizedBox(height: 8),
              _MenuContainer(
                items: [
                  _MenuItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Ride status alerts, promotions',
                    onTap: () => _showComingSoon(context, 'Notification Settings'),
                  ),
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    title: 'App Settings',
                    subtitle: 'Language, theme and display options',
                    onTap: () => _showComingSoon(context, 'App Settings'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // SUPPORT SECTION
              _SectionHeader(title: 'Support & Legal'),
              const SizedBox(height: 8),
              _MenuContainer(
                items: [
                  _MenuItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: '24/7 ride assistance and safety center',
                    onTap: () => _showComingSoon(context, 'Help & Support'),
                  ),
                  _MenuItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About ZYRO',
                    subtitle: 'Version 1.0.0 • Your Ride, Without the Wait',
                    onTap: () => _showAboutZyroDialog(context),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // LOGOUT BUTTON
              ZyroButton(
                text: 'Log Out',
                icon: Icons.logout_rounded,
                onPressed: () async {
                  _showLogoutConfirmation(context, authService);
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature settings will be available in the next release.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAboutZyroDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: ZyroTheme.brandGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.electric_scooter_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'About ZYRO',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: ZyroTheme.darkCharcoal,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ZYRO - Your Ride, Without the Wait.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ZyroTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'High-speed urban dispatching network designed to assign drivers in under 120 seconds.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: ZyroTheme.bodyText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Version 1.0.0 (Build 2026.1)',
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

  void _showEditProfileDialog(BuildContext context, String currentName) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ZyroTheme.darkCharcoal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                final user = AuthService().currentUser;
                if (user != null) {
                  await user.updateDisplayName(newName);
                  await user.reload();
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ZyroTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ZyroTheme.darkCharcoal,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of ZYRO?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: ZyroTheme.bodyText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: ZyroTheme.mutedText,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await authService.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ZyroTheme.errorRed,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Log Out',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: ZyroTheme.darkCharcoal,
      ),
    );
  }
}

class _MenuContainer extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuContainer({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZyroTheme.borderLight),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(height: 1, indent: 56, endIndent: 16, color: ZyroTheme.borderLight),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ZyroTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: ZyroTheme.primaryColor, size: 20),
      ),
      title: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ZyroTheme.darkCharcoal,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ZyroTheme.accentYellow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD48B00),
                ),
              ),
            ),
          ],
        ],
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
}

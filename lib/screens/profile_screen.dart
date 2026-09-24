import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import '../services/ride_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/zyro_button.dart';
import 'app_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'payment_history_screen.dart';
import 'payment_methods_screen.dart';
import 'personal_information_screen.dart';
import 'saved_places_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User? user;

  const ProfileScreen({
    super.key,
    this.user,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final DriverService _driverService = DriverService();
  final RideService _rideService = RideService();

  late User? _currentUser;
  String _userRole = 'rider';
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user ?? _authService.currentUser;
    _resolveUserRole();
  }

  Future<void> _resolveUserRole() async {
    if (_currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoadingRole = false;
        });
      }
      return;
    }

    try {
      final role = await _authService.getUserRole(_currentUser!.uid);
      if (mounted) {
        setState(() {
          _userRole = role;
          _isLoadingRole = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRole = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser ?? _authService.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: ZyroTheme.scaffoldBg(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_outlined,
                  size: 64, color: ZyroTheme.mutedText),
              const SizedBox(height: 16),
              Text(
                'No authenticated session found.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ZyroTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              ZyroButton(
                text: 'Go to Sign In',
                width: 180,
                onPressed: () => _authService.signOut(),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingRole) {
      return Scaffold(
        backgroundColor: ZyroTheme.scaffoldBg(context),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ZyroTheme.primaryColor),
          ),
        ),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _authService.watchUserProfile(user.uid),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data ?? {};
        final role = (userData['role'] as String?)?.toLowerCase() ?? _userRole;
        final isDriver = role == 'driver';

        final displayName = (userData['name'] as String?)?.isNotEmpty == true
            ? userData['name'] as String
            : (user.displayName?.isNotEmpty == true
                ? user.displayName!
                : (isDriver ? 'ZYRO Driver' : 'ZYRO Rider'));

        final email = user.email ?? (userData['email'] as String? ?? 'No email');
        final phone = (userData['phone'] as String?)?.isNotEmpty == true
            ? userData['phone'] as String
            : 'Not set';
        final photoUrl = user.photoURL ?? userData['photoUrl'] as String?;

        final vehicleType = (userData['vehicleType'] as String?) ?? 'bike';
        final vehicleNumber = (userData['vehicleNumber'] as String?) ?? '';

        return Scaffold(
          backgroundColor: ZyroTheme.scaffoldBg(context),
          appBar: AppBar(
            backgroundColor: ZyroTheme.cardBg(context),
            elevation: 0,
            centerTitle: false,
            title: Text(
              isDriver ? 'Driver Account' : 'Account & Profile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
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
                  // Top Profile Card
                  _buildHeaderCard(
                    context: context,
                    uid: user.uid,
                    displayName: displayName,
                    email: email,
                    phone: phone,
                    photoUrl: photoUrl,
                    isDriver: isDriver,
                  ),

                  const SizedBox(height: 16),

                  // Real-time Role-Aware Statistics Card
                  if (isDriver)
                    _buildDriverStatsAndStatus(user.uid, user)
                  else
                    _buildRiderStats(user.uid, user),

                  const SizedBox(height: 20),

                  // Vehicle Details Section (Driver only)
                  if (isDriver) ...[
                    _SectionHeader(title: 'Vehicle Information'),
                    const SizedBox(height: 8),
                    _buildVehicleInfoCard(
                      context: context,
                      vehicleType: vehicleType,
                      vehicleNumber: vehicleNumber,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 1 & 2: ACCOUNT SECTION
                  _SectionHeader(title: 'ACCOUNT'),
                  const SizedBox(height: 8),
                  _MenuContainer(
                    items: [
                      _MenuItem(
                        icon: Icons.person_outline_rounded,
                        title: 'Personal Information',
                        subtitle: 'Name, email, phone, and account details',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PersonalInformationScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuItem(
                        icon: Icons.bookmark_border_rounded,
                        title: 'Saved Places',
                        subtitle: 'Home, Work, and favorite drop-offs',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SavedPlacesScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3 & 4: PAYMENTS & WALLET SECTION
                  _SectionHeader(title: 'PAYMENTS & WALLET'),
                  const SizedBox(height: 8),
                  _MenuContainer(
                    items: [
                      _MenuItem(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Payment Methods / ZYRO Pay',
                        subtitle: 'UPI, saved cards, cash & wallet preferences',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaymentMethodsScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'Payment History',
                        subtitle: 'Trip receipts, breakdown & transaction logs',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaymentHistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 5 & 6: PREFERENCES SECTION
                  _SectionHeader(title: 'PREFERENCES'),
                  const SizedBox(height: 8),
                  _MenuContainer(
                    items: [
                      _MenuItem(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        subtitle: 'Ride status alerts, promotions & security',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuItem(
                        icon: Icons.settings_outlined,
                        title: 'App Settings',
                        subtitle: 'Theme, distance units, privacy & terms',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AppSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // SUPPORT SECTION
                  _SectionHeader(title: 'SUPPORT'),
                  const SizedBox(height: 8),
                  _MenuContainer(
                    items: [
                      _MenuItem(
                        icon: Icons.support_agent_rounded,
                        title: 'Help & 24/7 Safety Helpline',
                        subtitle: 'Emergency assistance and ride support',
                        onTap: () => _showHelpSupportDialog(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // LOGOUT BUTTON
                  ZyroButton(
                    text: 'Log Out',
                    icon: Icons.logout_rounded,
                    onPressed: () => _showLogoutConfirmation(context),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // UI WIDGET BUILDERS
  // ==========================================

  Widget _buildHeaderCard({
    required BuildContext context,
    required String uid,
    required String displayName,
    required String email,
    required String phone,
    required String? photoUrl,
    required bool isDriver,
  }) {
    final initials = displayName.trim().isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : 'Z';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ZyroTheme.borderColor(context)),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: ZyroTheme.primarySurfaceAdaptive(context),
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? Text(
                    initials,
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
                    color: ZyroTheme.textPrimary(context),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDriver
                            ? const Color(0xFFDCFCE7)
                            : ZyroTheme.primarySurfaceAdaptive(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isDriver ? 'Driver Account' : 'Rider Account',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDriver
                              ? const Color(0xFF15803D)
                              : ZyroTheme.primaryColor,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PersonalInformationScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ZyroTheme.scaffoldBg(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ZyroTheme.borderColor(context)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_outlined,
                                size: 11, color: ZyroTheme.mutedText),
                            const SizedBox(width: 3),
                            Text(
                              'Edit Profile',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ZyroTheme.textPrimary(context),
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
    );
  }

  Widget _buildRiderStats(String uid, User user) {
    return StreamBuilder<List<RideModel>>(
      stream: _rideService.watchRidesForRider(uid),
      builder: (context, snapshot) {
        final rides = snapshot.data ?? [];
        final completedRides =
            rides.where((r) => r.status == RideStatus.completed).toList();
        final cancelledCount =
            rides.where((r) => r.status == RideStatus.cancelled).length;

        final double totalSpent = completedRides.fold(
            0.0,
          (sum, r) => sum + r.fare,
        );

        final createdDate = user.metadata.creationTime;
        final memberSince = createdDate != null
            ? '${createdDate.day}/${createdDate.month}/${createdDate.year}'
            : 'Active';

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.route_rounded,
                    iconColor: ZyroTheme.primaryColor,
                    label: 'Completed Trips',
                    value: '${completedRides.length}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.currency_rupee_rounded,
                    iconColor: const Color(0xFF16A34A),
                    label: 'Total Spent',
                    value: '₹${totalSpent.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.cancel_outlined,
                    iconColor: ZyroTheme.errorRed,
                    label: 'Cancelled Trips',
                    value: '$cancelledCount',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.calendar_month_outlined,
                    iconColor: const Color(0xFF2563EB),
                    label: 'Member Since',
                    value: memberSince,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDriverStatsAndStatus(String uid, User user) {
    return StreamBuilder<DriverModel?>(
      stream: _driverService.watchDriver(uid),
      builder: (context, driverSnap) {
        final driver = driverSnap.data;
        final isOnline = driver?.isOnline ?? false;
        final isAvailable = driver?.isAvailable ?? false;
        final double avgRating = driver?.averageRating ?? 5.0;

        return StreamBuilder<List<RideModel>>(
          stream: _rideService.watchRidesForDriver(uid),
          builder: (context, ridesSnap) {
            final rides = ridesSnap.data ?? [];
            final completedRides =
                rides.where((r) => r.status == RideStatus.completed).toList();
            final totalCompleted = driver?.completedRidesCount != null &&
                    driver!.completedRidesCount > completedRides.length
                ? driver.completedRidesCount
                : completedRides.length;

            final double totalEarnings = completedRides.fold(
              0.0,
              (sum, r) => sum + r.fare,
            );

            final createdDate = user.metadata.creationTime;
            final driverSince = createdDate != null
                ? '${createdDate.day}/${createdDate.month}/${createdDate.year}'
                : 'Active';

            return Column(
              children: [
                // Live Status Banner
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xFFF0FDF4)
                        : ZyroTheme.cardBg(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOnline
                          ? const Color(0xFFBBF7D0)
                          : ZyroTheme.borderColor(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isOnline
                              ? 'ONLINE • Ready to receive rides'
                              : 'OFFLINE • Go to Driver Dashboard to start',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isOnline
                                ? const Color(0xFF166534)
                                : ZyroTheme.mutedText,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isAvailable ? 'AVAILABLE' : 'BUSY',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isAvailable
                                ? const Color(0xFF15803D)
                                : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Driver Statistics Grid
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.task_alt_rounded,
                        iconColor: const Color(0xFF16A34A),
                        label: 'Completed Rides',
                        value: '$totalCompleted',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.star_rounded,
                        iconColor: ZyroTheme.accentYellow,
                        label: 'Rating',
                        value: '${avgRating.toStringAsFixed(1)} ★',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.currency_rupee_rounded,
                        iconColor: const Color(0xFF15803D),
                        label: 'Total Earnings',
                        value: '₹${totalEarnings.toStringAsFixed(0)}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.calendar_month_outlined,
                        iconColor: const Color(0xFF2563EB),
                        label: 'Driver Since',
                        value: driverSince,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVehicleInfoCard({
    required BuildContext context,
    required String vehicleType,
    required String vehicleNumber,
  }) {
    IconData vehicleIcon;
    String displayType;

    switch (vehicleType.toLowerCase()) {
      case 'auto':
        vehicleIcon = Icons.electric_rickshaw_rounded;
        displayType = 'Auto Rickshaw';
        break;
      case 'cab':
        vehicleIcon = Icons.directions_car_rounded;
        displayType = 'Cab / Taxi';
        break;
      default:
        vehicleIcon = Icons.two_wheeler_rounded;
        displayType = 'Motorbike / Scooter';
    }

    final displayReg = vehicleNumber.isNotEmpty ? vehicleNumber : 'Not registered';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZyroTheme.borderColor(context)),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZyroTheme.primarySurfaceAdaptive(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(vehicleIcon, color: ZyroTheme.primaryColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayType,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ZyroTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Plate Number: $displayReg',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ZyroTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ACTION DIALOGS & HANDLERS
  // ==========================================

  void _showHelpSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZyroTheme.cardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.headset_mic_rounded, color: ZyroTheme.primaryColor),
            const SizedBox(width: 10),
            Text(
              'ZYRO Support',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: ZyroTheme.textPrimary(context),
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '24/7 Urban Mobility Helpline',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ZyroTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Emergency Safety Hotline: 1800-ZYRO-911\n• Email: support@zyro.app\n• In-Ride Live SOS: Available directly on active ride screen.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: ZyroTheme.textSecondary(context),
                height: 1.5,
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

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZyroTheme.cardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ZyroTheme.textPrimary(context),
          ),
        ),
        content: Text(
          'Are you sure you want to log out of ZYRO?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: ZyroTheme.textSecondary(context),
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
              await _authService.signOut();
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

// ==========================================
// REUSABLE HELPER WIDGETS
// ==========================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZyroTheme.borderColor(context)),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ZyroTheme.mutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ZyroTheme.textPrimary(context),
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
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: ZyroTheme.mutedText,
        letterSpacing: 0.8,
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
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZyroTheme.borderColor(context)),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: ZyroTheme.borderColor(context)),
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
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
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
          color: ZyroTheme.primarySurfaceAdaptive(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: ZyroTheme.primaryColor,
          size: 20,
        ),
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
}

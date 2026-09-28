import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/driver_dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';
import 'services/preferences_service.dart';
import 'theme/zyro_theme.dart';
import 'widgets/zyro_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with DefaultFirebaseOptions
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('[FIREBASE] PROJECT: ${Firebase.app().options.projectId}');

  runApp(const ZyroApp());
}

class ZyroApp extends StatelessWidget {
  const ZyroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: PreferencesService.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'ZYRO',
          debugShowCheckedModeBanner: false,
          themeMode: currentThemeMode,
          theme: ZyroTheme.lightTheme,
          darkTheme: ZyroTheme.darkTheme,
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Central AuthGate: Decides which screen to render based on Firebase Auth state
/// and the authoritative role stored in Firestore (`users/{uid}`).
/// - user == null      -> LoginScreen
/// - role == "driver"  -> DriverDashboardScreen
/// - role == "rider"   -> MainNavigationScreen (Rider Home)
/// - missing role      -> _MissingRoleScreen
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  final PreferencesService _prefsService = PreferencesService();
  String? _initializedUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        debugPrint('[AUTH GATE] authSnapshot state: ${authSnapshot.connectionState}, hasData: ${authSnapshot.hasData}, user: ${authSnapshot.data?.uid}');

        // While Firebase Auth is verifying local tokens
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen(
            statusText: 'Connecting to ZYRO...',
          );
        }

        if (authSnapshot.hasError) {
          debugPrint('[AUTH ERROR] AuthGate authSnapshot error: ${authSnapshot.error}');
          return _AuthMessageScreen(
            icon: Icons.error_outline_rounded,
            iconColor: ZyroTheme.errorRed,
            title: 'Authentication Error',
            description: 'Authentication state error: ${authSnapshot.error}',
            primaryButtonText: 'Retry',
            onPrimaryPressed: () => setState(() {}),
          );
        }

        final user = authSnapshot.data;

        // User is not logged in: clear local session UID and display Login
        if (user == null) {
          _initializedUid = null;
          return const LoginScreen();
        }

        // Initialize user preferences on session start
        if (_initializedUid != user.uid) {
          _initializedUid = user.uid;
          _prefsService.initThemeMode(user.uid);
        }

        // Real-time authoritative role resolution
        return StreamBuilder<String?>(
          key: ValueKey('auth_gate_role_${user.uid}'),
          stream: _authService.watchUserRole(user.uid),
          builder: (context, roleSnapshot) {
            debugPrint('[AUTH GATE] roleSnapshot state: ${roleSnapshot.connectionState}, hasData: ${roleSnapshot.hasData}, role: ${roleSnapshot.data}, hasError: ${roleSnapshot.hasError}');

            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingScreen(
                statusText: 'Verifying account role...',
              );
            }

            if (roleSnapshot.hasError) {
              debugPrint('[AUTH ERROR] AuthGate roleSnapshot error: ${roleSnapshot.error}');
              return _AuthMessageScreen(
                icon: Icons.cloud_off_rounded,
                iconColor: ZyroTheme.errorRed,
                title: 'Unable to Load Profile',
                description:
                    'Error loading account details from server: ${roleSnapshot.error}',
                primaryButtonText: 'Retry',
                onPrimaryPressed: () => setState(() {}),
                secondaryButtonText: 'Sign Out',
                onSecondaryPressed: () => _authService.signOut(),
              );
            }

            final role = roleSnapshot.data;

            // snapshot has data but document doesn't exist / role is missing
            if (role == null || role.isEmpty) {
              return _AuthMessageScreen(
                icon: Icons.error_outline_rounded,
                iconColor: ZyroTheme.errorRed,
                title: 'User Profile Missing',
                description:
                    'User profile is missing for UID ${user.uid}. Please sign out and create a new account.',
                primaryButtonText: 'Sign Out',
                onPrimaryPressed: () => _authService.signOut(),
              );
            }

            // Driver Account
            if (role == 'driver') {
              debugPrint('[AUTH GATE] Verified driver — rendering DriverDashboardScreen');
              return const DriverDashboardScreen();
            }

            // Rider Account
            if (role == 'rider') {
              debugPrint('[AUTH GATE] Verified rider — rendering MainNavigationScreen');
              return MainNavigationScreen(user: user);
            }

            // Unknown or unsupported role
            debugPrint('[AUTH GATE] Unknown role "$role" for UID ${user.uid}');
            return _AuthMessageScreen(
              icon: Icons.warning_amber_rounded,
              iconColor: ZyroTheme.accentYellow,
              title: 'Unsupported Account Role',
              description:
                  'Your account has the role "$role", which is not recognized by ZYRO. Please sign out or contact customer support.',
              primaryButtonText: 'Sign Out',
              onPrimaryPressed: () => _authService.signOut(),
            );
          },
        );
      },
    );
  }
}

/// Loading screen displayed during auth token check or role resolution
class _AuthLoadingScreen extends StatelessWidget {
  final String statusText;

  const _AuthLoadingScreen({required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: ZyroTheme.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33F2542D),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.electric_scooter_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ZyroTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ZyroTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic message/error screen with action buttons
class _AuthMessageScreen extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String primaryButtonText;
  final VoidCallback onPrimaryPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;

  const _AuthMessageScreen({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: ZyroTheme.cardBg(context),
                borderRadius: BorderRadius.circular(28),
                boxShadow: ZyroTheme.cardShadow(context),
                border: Border.all(color: ZyroTheme.borderColor(context)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 30),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: ZyroTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: ZyroTheme.textSecondary(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ZyroButton(
                    text: primaryButtonText,
                    onPressed: onPrimaryPressed,
                  ),
                  if (secondaryButtonText != null && onSecondaryPressed != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onSecondaryPressed,
                      child: Text(
                        secondaryButtonText!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ZyroTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

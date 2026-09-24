import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'screens/driver_dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';
import 'services/preferences_service.dart';
import 'theme/zyro_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

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
          title: 'ZYRO - Your Ride, Without the Wait',
          debugShowCheckedModeBanner: false,
          theme: ZyroTheme.lightTheme,
          darkTheme: ZyroTheme.darkTheme,
          themeMode: currentThemeMode,
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Dynamic Role-Aware Authentication Gatekeeper
///
/// Directs users strictly according to their authoritative Firestore role:
/// - role == "driver" -> DriverDashboardScreen
/// - role == "rider"  -> MainNavigationScreen (Rider Home)
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
      builder: (context, snapshot) {
        // While Firebase is checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
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
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ZyroTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // User is logged in: resolve authoritative role from users/{uid}
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;

          if (_initializedUid != user.uid) {
            _initializedUid = user.uid;
            _prefsService.initThemeMode(user.uid);
          }

          return FutureBuilder<String>(
            future: _authService.getUserRole(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ZyroTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final role = roleSnapshot.data ?? 'rider';

              if (role == 'driver') {
                return const DriverDashboardScreen();
              } else {
                return MainNavigationScreen(user: user);
              }
            },
          );
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}

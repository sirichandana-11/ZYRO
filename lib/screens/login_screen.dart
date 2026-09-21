import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/google_button.dart';
import '../widgets/zyro_brand_header.dart';
import '../widgets/zyro_button.dart';
import '../widgets/zyro_text_field.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZyroTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signInWithEmailPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // AuthGate stream listener will automatically switch to HomeScreen
    } catch (errorMessage) {
      _showErrorSnackBar(errorMessage.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        // User closed or canceled the popup
        return;
      }
      // AuthGate stream listener will automatically switch to HomeScreen
    } catch (errorMessage) {
      _showErrorSnackBar(errorMessage.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final resetEmailController =
            TextEditingController(text: _emailController.text);
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ZyroTheme.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ZyroTheme.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: ZyroTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reset Password',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: ZyroTheme.darkCharcoal,
                              ),
                            ),
                            Text(
                              'We\'ll send a Firebase recovery email',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: ZyroTheme.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ZyroTextField(
                    label: 'Email',
                    hint: 'Enter your registered email',
                    controller: resetEmailController,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  ZyroButton(
                    text: 'Send Recovery Link',
                    isLoading: isSubmitting,
                    onPressed: () async {
                      final email = resetEmailController.text.trim();
                      if (email.isEmpty) {
                        return;
                      }

                      setModalState(() {
                        isSubmitting = true;
                      });

                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      try {
                        await _authService.sendPasswordResetEmail(email: email);
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: ZyroTheme.darkCharcoal,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            content: Row(
                              children: [
                                const Icon(Icons.mark_email_read_rounded,
                                    color: ZyroTheme.accentYellow),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Recovery link sent to $email',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } catch (e) {
                        setModalState(() {
                          isSubmitting = false;
                        });
                        _showErrorSnackBar(e.toString());
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToSignup() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SignupScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZyroTheme.backgroundLight,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth >= 768;

          if (isWideScreen) {
            return _buildWideScreenLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  /// Split Desktop / Tablet Layout
  Widget _buildWideScreenLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Row(
          children: [
            // Left Banner
            const Expanded(
              flex: 5,
              child: ZyroBrandHeaderDesktop(),
            ),

            // Right Form Surface
            Expanded(
              flex: 6,
              child: Container(
                color: Colors.white,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 40,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: _buildFormCard(isMobile: false),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mobile Portrait Layout (Optimized for Android phones & Emulator)
  Widget _buildMobileLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // Top Brand Banner Header
              const ZyroBrandHeaderMobile(),

              // Overlapping White Form Container
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: ZyroTheme.softCardShadow,
                      border: Border.all(
                        color: ZyroTheme.borderLight.withValues(alpha: 0.6),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                    child: _buildFormCard(isMobile: true),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// The Core Login Form
  Widget _buildFormCard({required bool isMobile}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Title
          Text(
            'Welcome back!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ZyroTheme.mutedText,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Login to ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 22 : 26,
                  fontWeight: FontWeight.w800,
                  color: ZyroTheme.darkCharcoal,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                'ZYRO',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 23 : 27,
                  fontWeight: FontWeight.w900,
                  color: ZyroTheme.primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your credentials to access your rides and rewards.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: ZyroTheme.bodyText.withValues(alpha: 0.8),
            ),
          ),

          const SizedBox(height: 22),

          // Google Button
          GoogleButton(
            text: 'Continue with Google',
            isLoading: _isGoogleLoading,
            onPressed: _handleGoogleLogin,
          ),

          const SizedBox(height: 18),

          // OR Divider
          Row(
            children: [
              const Expanded(
                child: Divider(
                  color: ZyroTheme.borderLight,
                  thickness: 1.2,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'or with email',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: ZyroTheme.mutedText,
                  ),
                ),
              ),
              const Expanded(
                child: Divider(
                  color: ZyroTheme.borderLight,
                  thickness: 1.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Email Field
          ZyroTextField(
            label: 'Email',
            hint: 'Enter your email address',
            controller: _emailController,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _authService.validateEmail,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 16),

          // Password Field
          ZyroTextField(
            label: 'Password',
            hint: 'Enter your password',
            controller: _passwordController,
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: _authService.validatePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
          ),

          const SizedBox(height: 10),

          // Forgot Password link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot password?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ZyroTheme.primaryColor,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Main Login Button
          ZyroButton(
            text: 'Login',
            isLoading: _isLoading,
            onPressed: _handleLogin,
          ),

          const SizedBox(height: 20),

          // Sign up link
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    color: ZyroTheme.bodyText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                GestureDetector(
                  onTap: _navigateToSignup,
                  child: Text(
                    'Sign up',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: ZyroTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Language Selector Footer
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.language_rounded,
                  size: 14,
                  color: ZyroTheme.mutedText.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'English (US)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ZyroTheme.mutedText,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: ZyroTheme.mutedText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

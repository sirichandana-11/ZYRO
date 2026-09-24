import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/zyro_button.dart';
import '../widgets/zyro_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  String _selectedRole = 'rider'; // 'rider' | 'driver'
  String _selectedVehicleType = 'bike'; // 'bike' | 'auto' | 'cab'
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _vehicleNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signUpWithEmailPassword(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
        role: _selectedRole,
        phone: _phoneController.text,
        vehicleType: _selectedVehicleType,
        vehicleNumber: _vehicleNumberController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZyroTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedRole == 'driver'
                      ? 'Driver account created! Welcome to ZYRO Partner.'
                      : 'Rider account created! Welcome to ZYRO.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Pop back; AuthGate stream listener will automatically route based on role
      Navigator.of(context).pop();
    } catch (errorMessage) {
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
                  errorMessage.toString(),
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = _selectedRole == 'driver';

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: ZyroTheme.textPrimary(context), size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to login',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: ZyroTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: ZyroTheme.cardShadow(context),
                  border: Border.all(
                    color: ZyroTheme.borderColor(context),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Branding
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ZyroTheme.primarySurfaceAdaptive(context),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isDriver
                                  ? Icons.local_taxi_rounded
                                  : Icons.electric_scooter_rounded,
                              color: ZyroTheme.primaryColor,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDriver
                                    ? 'Driver Registration'
                                    : 'Create Account',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: ZyroTheme.textPrimary(context),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                isDriver
                                    ? 'Join the ZYRO high-speed driver fleet'
                                    : 'Join ZYRO for <120s ride dispatches',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: ZyroTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ACCOUNT TYPE SELECTOR
                      Text(
                        'Select Account Type',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ZyroTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: ZyroTheme.isDarkMode(context)
                              ? ZyroTheme.surfaceDarkElevated
                              : ZyroTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ZyroTheme.borderColor(context)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedRole = 'rider';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !isDriver ? ZyroTheme.cardBg(context) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: !isDriver
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 18,
                                        color: !isDriver
                                            ? ZyroTheme.primaryColor
                                            : ZyroTheme.mutedText,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Rider',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: !isDriver
                                              ? ZyroTheme.textPrimary(context)
                                              : ZyroTheme.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedRole = 'driver';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDriver ? ZyroTheme.cardBg(context) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: isDriver
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.local_taxi_rounded,
                                        size: 18,
                                        color: isDriver
                                            ? ZyroTheme.primaryColor
                                            : ZyroTheme.mutedText,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Driver',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isDriver
                                              ? ZyroTheme.textPrimary(context)
                                              : ZyroTheme.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Full Name
                      ZyroTextField(
                        label: isDriver ? 'Driver Full Name' : 'Full Name',
                        hint: 'Enter your full name',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline_rounded,
                        keyboardType: TextInputType.name,
                        validator: _authService.validateFullName,
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: 14),

                      // Email
                      ZyroTextField(
                        label: 'Email',
                        hint: 'Enter your email address',
                        controller: _emailController,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: _authService.validateEmail,
                        textInputAction: TextInputAction.next,
                      ),

                      // DRIVER SPECIFIC FIELDS
                      if (isDriver) ...[
                        const SizedBox(height: 14),
                        ZyroTextField(
                          label: 'Phone Number',
                          hint: '+91 98765 43210',
                          controller: _phoneController,
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Phone number is required for drivers';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle Type',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: ZyroTheme.darkCharcoal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedVehicleType,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: ZyroTheme.borderLight),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'bike', child: Text('ZYRO Bike (Two-Wheeler)')),
                                DropdownMenuItem(
                                    value: 'auto',
                                    child: Text('ZYRO Auto (Rickshaw)')),
                                DropdownMenuItem(
                                    value: 'cab',
                                    child: Text('ZYRO Prime Cab (Car)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedVehicleType = val;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ZyroTextField(
                          label: 'Vehicle Registration Number',
                          hint: 'e.g. KA-01-AB-1234',
                          controller: _vehicleNumberController,
                          prefixIcon: Icons.pin_outlined,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vehicle number is required';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Password
                      ZyroTextField(
                        label: 'Password',
                        hint: 'Create a strong password (min 6 chars)',
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: _authService.validatePassword,
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: 14),

                      // Confirm Password
                      ZyroTextField(
                        label: 'Confirm Password',
                        hint: 'Re-enter your password',
                        controller: _confirmPasswordController,
                        prefixIcon: Icons.lock_clock_outlined,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleSignup(),
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      ZyroButton(
                        text: isDriver ? 'Register as Driver' : 'Create Rider Account',
                        isLoading: _isLoading,
                        onPressed: _handleSignup,
                      ),

                      const SizedBox(height: 20),

                      // Already have an account
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                color: ZyroTheme.bodyText,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Text(
                                'Log in',
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

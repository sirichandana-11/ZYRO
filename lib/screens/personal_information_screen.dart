import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/zyro_button.dart';

class PersonalInformationScreen extends StatefulWidget {
  final User? user;

  const PersonalInformationScreen({super.key, this.user});

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.user ?? _authService.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Personal Information')),
        body: const Center(child: Text('Please log in to view personal information.')),
      );
    }

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: ZyroTheme.cardBg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ZyroTheme.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Personal Information',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.textPrimary(context),
          ),
        ),
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit_outlined, size: 16, color: ZyroTheme.primaryColor),
              label: Text(
                'Edit',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: ZyroTheme.primaryColor,
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _authService.watchUserProfile(currentUser.uid),
        builder: (context, snapshot) {
          final userData = snapshot.data ?? {};
          final name = (userData['name'] as String?)?.isNotEmpty == true
              ? userData['name'] as String
              : (currentUser.displayName ?? 'ZYRO User');
          final email = currentUser.email ?? (userData['email'] as String? ?? 'Not registered');
          final phone = (userData['phone'] as String?)?.isNotEmpty == true
              ? userData['phone'] as String
              : '';
          final role = (userData['role'] as String?) ?? 'rider';
          final createdDate = currentUser.metadata.creationTime;
          final memberSince = createdDate != null
              ? '${createdDate.day}/${createdDate.month}/${createdDate.year}'
              : 'Active';

          if (!_isEditing) {
            _nameController.text = name;
            _phoneController.text = phone;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Photo & Name Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ZyroTheme.cardBg(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ZyroTheme.borderColor(context)),
                      boxShadow: ZyroTheme.softCardShadow,
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: ZyroTheme.primarySurfaceAdaptive(context),
                          child: Text(
                            name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'Z',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: ZyroTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ZyroTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: role == 'driver' ? const Color(0xFFDCFCE7) : ZyroTheme.primarySurfaceAdaptive(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${role.toUpperCase()} ACCOUNT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: role == 'driver' ? const Color(0xFF15803D) : ZyroTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Fields Container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ZyroTheme.cardBg(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ZyroTheme.borderColor(context)),
                      boxShadow: ZyroTheme.softCardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACCOUNT DETAILS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: ZyroTheme.mutedText,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Full Name
                        if (_isEditing)
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: _authService.validateFullName,
                          )
                        else
                          _buildDetailRow(context, Icons.person_outline_rounded, 'Full Name', name),

                        Divider(height: 24, color: ZyroTheme.borderColor(context)),

                        // Phone Number
                        if (_isEditing)
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: _authService.validatePhone,
                          )
                        else
                          _buildDetailRow(
                            context,
                            Icons.phone_outlined,
                            'Phone Number',
                            phone.isNotEmpty ? phone : 'Not provided',
                          ),

                        Divider(height: 24, color: ZyroTheme.borderColor(context)),

                        // Email Address (Read-only)
                        _buildDetailRow(
                          context,
                          Icons.email_outlined,
                          'Email Address',
                          email,
                          trailing: 'Verified',
                        ),

                        Divider(height: 24, color: ZyroTheme.borderColor(context)),

                        // Member Since
                        _buildDetailRow(
                          context,
                          Icons.calendar_today_outlined,
                          'Member Since',
                          memberSince,
                        ),

                        Divider(height: 24, color: ZyroTheme.borderColor(context)),

                        // UID
                        _buildDetailRow(
                          context,
                          Icons.fingerprint_rounded,
                          'Account ID',
                          currentUser.uid,
                        ),
                      ],
                    ),
                  ),

                  if (_isEditing) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: ZyroTheme.borderColor(context)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _isSaving
                                  ? null
                                  : () {
                                      setState(() {
                                        _isEditing = false;
                                        _nameController.text = name;
                                        _phoneController.text = phone;
                                      });
                                    },
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ZyroTheme.textPrimary(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ZyroButton(
                            text: _isSaving ? 'Saving...' : 'Save Changes',
                            isLoading: _isSaving,
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    setState(() {
                                      _isSaving = true;
                                    });

                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      await _authService.updateUserProfile(
                                        uid: currentUser.uid,
                                        name: _nameController.text.trim(),
                                        phone: _phoneController.text.trim(),
                                      );

                                      if (mounted) {
                                        setState(() {
                                          _isEditing = false;
                                          _isSaving = false;
                                        });
                                        messenger.showSnackBar(
                                          SnackBar(
                                            backgroundColor: ZyroTheme.successGreen,
                                            content: Text(
                                              'Profile updated successfully!',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() {
                                          _isSaving = false;
                                        });
                                        messenger.showSnackBar(
                                          SnackBar(
                                            backgroundColor: ZyroTheme.errorRed,
                                            content: Text(
                                              'Error updating profile: $e',
                                              style: GoogleFonts.plusJakartaSans(color: Colors.white),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {String? trailing}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ZyroTheme.primarySurfaceAdaptive(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ZyroTheme.primaryColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: ZyroTheme.mutedText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ZyroTheme.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              trailing,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF15803D),
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/zyro_theme.dart';

enum LegalDocumentType { privacyPolicy, termsOfService }

class LegalScreen extends StatelessWidget {
  final LegalDocumentType type;

  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isPrivacy = type == LegalDocumentType.privacyPolicy;
    final title = isPrivacy ? 'Privacy Policy' : 'Terms of Service';

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          title,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const BouncingScrollPhysics(),
        child: Container(
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
              Row(
                children: [
                  Icon(
                    isPrivacy ? Icons.privacy_tip_outlined : Icons.description_outlined,
                    color: ZyroTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ZYRO Urban Mobility',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ZyroTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Last Updated: September 2026',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: ZyroTheme.mutedText,
                ),
              ),
              Divider(height: 24, color: ZyroTheme.borderColor(context)),
              if (isPrivacy) ..._buildPrivacyContent(context) else ..._buildTermsContent(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPrivacyContent(BuildContext context) {
    return [
      _buildSection(
        context,
        '1. Information We Collect',
        'We collect information you provide directly (such as name, phone number, email address), location data during active trips to calculate routes and matching, and device telemetry to ensure safety and system reliability.',
      ),
      _buildSection(
        context,
        '2. Use of Location Data',
        'Background and foreground location permissions are utilized exclusively to match nearby riders with available drivers, provide live route navigation, verify pickup/drop-off points, and ensure emergency SOS monitoring.',
      ),
      _buildSection(
        context,
        '3. Payment Information Security',
        'ZYRO does not store raw credit card numbers, CVV codes, bank passwords, or UPI PINs. All payment preferences stored in your account represent masked display references only.',
      ),
      _buildSection(
        context,
        '4. Data Retention & Deletion',
        'You have the right to request deletion of your account and personal identifiers at any time through our Support channels. Aggregated trip records are retained strictly for regulatory and auditing compliance.',
      ),
      _buildSection(
        context,
        '5. Contact for Privacy Inquiries',
        'For data privacy questions or requests, contact our Data Protection Officer at privacy@zyro.app.',
      ),
    ];
  }

  List<Widget> _buildTermsContent(BuildContext context) {
    return [
      _buildSection(
        context,
        '1. Acceptance of Terms',
        'By creating an account or accessing the ZYRO mobility platform as a Rider or Driver, you agree to comply with these terms of service and all applicable local transportation laws.',
      ),
      _buildSection(
        context,
        '2. Platform Services',
        'ZYRO provides a technology platform connecting independent riders and verified drivers. ZYRO facilitates ride dispatching, route estimation, and fare calculation based on distance and dynamic urban demand.',
      ),
      _buildSection(
        context,
        '3. User Conduct & Safety',
        'Users must maintain professional conduct. Zero tolerance policies apply to harassment, reckless driving, unauthorized vehicle substitutions, or fraudulent booking activities.',
      ),
      _buildSection(
        context,
        '4. Fares and Payments',
        'Fares are calculated and presented prior to booking confirmation. Any toll fees, parking charges, or dynamic surge rates will be itemized in the final trip receipt.',
      ),
      _buildSection(
        context,
        '5. Cancellation Policy',
        'Riders and drivers may cancel rides under standard platform grace periods. Frequent abusive cancellations may result in temporary account restrictions.',
      ),
    ];
  }

  Widget _buildSection(BuildContext context, String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: ZyroTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: ZyroTheme.textSecondary(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

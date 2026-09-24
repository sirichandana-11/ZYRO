import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/payment_method_model.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/zyro_button.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final User? user;

  const PaymentMethodsScreen({super.key, this.user});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final AuthService _authService = AuthService();
  final PaymentService _paymentService = PaymentService();

  @override
  Widget build(BuildContext context) {
    final user = widget.user ?? _authService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Methods')),
        body: const Center(child: Text('Please log in to manage payment methods.')),
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
          'Payment Methods & Wallet',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.textPrimary(context),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMethodSheet(context, user.uid),
        backgroundColor: ZyroTheme.primaryColor,
        icon: const Icon(Icons.add_card_rounded, color: Colors.white),
        label: Text(
          'Add Method',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ZYRO Pay Wallet Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: ZyroTheme.brandGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: ZyroTheme.softCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ZYRO PAY WALLET',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Direct Checkout',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '₹0.00',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fast 1-tap ride settlement via connected UPI or Cash',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Cash on Ride Option (Default standard)
            Text(
              'DEFAULT CASH PAYMENT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: ZyroTheme.mutedText,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZyroTheme.cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZyroTheme.borderColor(context)),
                boxShadow: ZyroTheme.softCardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash on Ride',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ZyroTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pay directly to driver after ride completion',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: ZyroTheme.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ALWAYS ACTIVE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Saved Payment Methods
            Text(
              'SAVED PAYMENT PREFERENCES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: ZyroTheme.mutedText,
              ),
            ),
            const SizedBox(height: 10),

            StreamBuilder<List<PaymentMethodModel>>(
              stream: _paymentService.watchPaymentMethods(user.uid),
              builder: (context, snapshot) {
                final methods = snapshot.data ?? [];

                if (methods.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ZyroTheme.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ZyroTheme.borderColor(context)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 36, color: ZyroTheme.mutedText),
                        const SizedBox(height: 10),
                        Text(
                          'No custom payment methods saved',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ZyroTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add your UPI ID or Card reference for quick digital checkout.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ZyroTheme.mutedText),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: methods.map((method) => _buildMethodCard(context, user.uid, method)).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Security Notice Container
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
                  const Icon(Icons.security_rounded, size: 20, color: ZyroTheme.primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ZYRO Security Invariant: We never store CVVs, PINs, or raw bank credentials. Saved digital methods store only verified UPI handles or masked card numbers for display checkout preferences.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: ZyroTheme.textPrimary(context),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard(BuildContext context, String uid, PaymentMethodModel method) {
    IconData icon;
    Color iconColor;
    String subtitle;

    if (method.type == 'upi') {
      icon = Icons.qr_code_2_rounded;
      iconColor = const Color(0xFF2563EB);
      subtitle = method.upiId ?? 'UPI Handle';
    } else {
      icon = Icons.credit_card_rounded;
      iconColor = const Color(0xFF9333EA);
      subtitle = 'Card ending in •••• ${method.last4 ?? '0000'}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: method.isDefault ? ZyroTheme.primaryColor : ZyroTheme.borderColor(context),
          width: method.isDefault ? 1.5 : 1.0,
        ),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Row(
          children: [
            Text(
              method.displayName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: ZyroTheme.textPrimary(context),
              ),
            ),
            if (method.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ZyroTheme.primarySurfaceAdaptive(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DEFAULT',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ZyroTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ZyroTheme.mutedText),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: ZyroTheme.mutedText),
          onSelected: (val) {
            if (val == 'default') {
              _paymentService.setDefaultPaymentMethod(uid: uid, paymentMethodId: method.id);
            } else if (val == 'delete') {
              _paymentService.deletePaymentMethod(uid: uid, paymentMethodId: method.id);
            }
          },
          itemBuilder: (ctx) => [
            if (!method.isDefault)
              const PopupMenuItem(
                value: 'default',
                child: Text('Set as Default'),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Remove', style: TextStyle(color: ZyroTheme.errorRed)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMethodSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddPaymentMethodSheet(uid: uid, paymentService: _paymentService),
    );
  }
}

class _AddPaymentMethodSheet extends StatefulWidget {
  final String uid;
  final PaymentService paymentService;

  const _AddPaymentMethodSheet({required this.uid, required this.paymentService});

  @override
  State<_AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<_AddPaymentMethodSheet> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'upi';
  final _nameController = TextEditingController();
  final _upiController = TextEditingController();
  final _last4Controller = TextEditingController();
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _upiController.dispose();
    _last4Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZyroTheme.borderColor(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Payment Preference',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ZyroTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 16),

              // Type Switcher
              Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.qr_code_2_rounded, size: 16),
                    label: const Text('UPI ID'),
                    selected: _selectedType == 'upi',
                    selectedColor: ZyroTheme.primaryColor,
                    backgroundColor: ZyroTheme.scaffoldBg(context),
                    labelStyle: TextStyle(
                      color: _selectedType == 'upi' ? Colors.white : ZyroTheme.textPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (val) => setState(() => _selectedType = 'upi'),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    avatar: const Icon(Icons.credit_card_rounded, size: 16),
                    label: const Text('Debit/Credit Card'),
                    selected: _selectedType == 'card',
                    selectedColor: ZyroTheme.primaryColor,
                    backgroundColor: ZyroTheme.scaffoldBg(context),
                    labelStyle: TextStyle(
                      color: _selectedType == 'card' ? Colors.white : ZyroTheme.textPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (val) => setState(() => _selectedType = 'card'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Account / Card Nickname',
                  hintText: _selectedType == 'upi' ? 'e.g. Google Pay, PhonePe' : 'e.g. HDFC Salary Card',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a nickname' : null,
              ),

              const SizedBox(height: 14),

              if (_selectedType == 'upi') ...[
                TextFormField(
                  controller: _upiController,
                  decoration: InputDecoration(
                    labelText: 'UPI Virtual Address',
                    hintText: 'e.g. username@okhdfcbank',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'UPI ID is required';
                    if (!val.contains('@')) return 'Enter a valid UPI ID format';
                    return null;
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _last4Controller,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: 'Last 4 Digits of Card',
                    hintText: '4242',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Only last 4 digits stored for checkout identification.',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length != 4 || int.tryParse(val) == null) {
                      return 'Enter exactly 4 digits';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 10),

              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                title: Text(
                  'Set as default payment preference',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: ZyroTheme.textPrimary(context)),
                ),
                onChanged: (val) => setState(() => _isDefault = val ?? false),
              ),

              const SizedBox(height: 16),

              ZyroButton(
                text: _isSaving ? 'Saving...' : 'Save Payment Method',
                isLoading: _isSaving,
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _isSaving = true);

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);

                        try {
                          await widget.paymentService.addPaymentMethod(
                            uid: widget.uid,
                            type: _selectedType,
                            displayName: _nameController.text.trim(),
                            upiId: _selectedType == 'upi' ? _upiController.text.trim() : null,
                            last4: _selectedType == 'card' ? _last4Controller.text.trim() : null,
                            isDefault: _isDefault,
                          );

                          if (!mounted) return;
                          navigator.pop();
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: ZyroTheme.successGreen,
                              content: Text('Payment method added successfully!'),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          setState(() => _isSaving = false);
                          scaffoldMessenger.showSnackBar(
                            SnackBar(backgroundColor: ZyroTheme.errorRed, content: Text('Error: $e')),
                          );
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

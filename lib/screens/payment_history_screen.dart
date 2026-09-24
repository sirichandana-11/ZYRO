import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ride_model.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/zyro_button.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final User? user;

  const PaymentHistoryScreen({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final paymentService = PaymentService();
    final currentUser = user ?? authService.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment History')),
        body: const Center(child: Text('Please log in to view payment history.')),
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
          'Payment History',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.textPrimary(context),
          ),
        ),
      ),
      body: StreamBuilder<List<RideModel>>(
        stream: paymentService.watchPaymentHistory(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rides = snapshot.data ?? [];

          if (rides.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ZyroTheme.primarySurfaceAdaptive(context),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: ZyroTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Payment Receipts',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ZyroTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your completed trip invoices and transaction receipts will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: ZyroTheme.mutedText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ZyroButton(
                      text: 'Book a Ride',
                      width: 180,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: rides.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ride = rides[index];
              return _buildReceiptCard(context, ride);
            },
          );
        },
      ),
    );
  }

  Widget _buildReceiptCard(BuildContext context, RideModel ride) {
    final date = ride.requestedAt;
    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : 'Completed';

    final pickup = ride.pickupAddress?.isNotEmpty == true ? ride.pickupAddress! : 'Pickup Location';
    final drop = ride.destinationAddress?.isNotEmpty == true ? ride.destinationAddress! : 'Destination Location';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZyroTheme.borderColor(context)),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${ride.fare.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ZyroTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ZyroTheme.scaffoldBg(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ZyroTheme.borderColor(context)),
                ),
                child: Text(
                  'PAID • CASH / ZYRO',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dateStr,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ZyroTheme.mutedText,
            ),
          ),
          Divider(height: 20, color: ZyroTheme.borderColor(context)),
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded, size: 14, color: ZyroTheme.successGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: ZyroTheme.textPrimary(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: ZyroTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  drop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: ZyroTheme.textPrimary(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ride ID: ${ride.id.length > 8 ? ride.id.substring(0, 8) : ride.id}',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: ZyroTheme.mutedText),
              ),
              Text(
                '${ride.rideType.toUpperCase()} TRIP',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ZyroTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

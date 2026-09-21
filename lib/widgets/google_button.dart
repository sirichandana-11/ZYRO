import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/zyro_theme.dart';

class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  const GoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.text = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ZyroTheme.borderLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF191C21).withValues(alpha: 0.03),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onPressed,
          splashColor: ZyroTheme.primarySurface,
          highlightColor: ZyroTheme.primarySurface.withValues(alpha: 0.5),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ZyroTheme.primaryColor,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _GoogleLogo(),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ZyroTheme.darkCharcoal,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Custom painted Google 'G' Logo for sharp rendering without asset loading latency
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    // Google Blue
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(w, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        0,
        -0.785, // -45 deg
        false,
      )
      ..close();
    canvas.drawPath(bluePath, paint);

    // Draw Google 4-color arcs
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Red (Top)
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, -0.785, -2.356, false)
      ..close();
    canvas.drawPath(redPath, paint);

    // Yellow (Left)
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, -3.141, -1.047, false)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Green (Bottom)
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, -4.188, -1.309, false)
      ..close();
    canvas.drawPath(greenPath, paint);

    // White inner cutout
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.58, innerPaint);

    // Blue horizontal bar
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(center.dx, center.dy - radius * 0.22, w * 0.98, center.dy + radius * 0.22),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(barRect, barPaint);

    // White wedge inside right
    final cutPaint = Paint()..color = Colors.white;
    final cutPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + radius * 0.45, center.dy - radius * 0.5)
      ..lineTo(center.dx + radius * 0.45, center.dy)
      ..close();
    canvas.drawPath(cutPath, cutPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

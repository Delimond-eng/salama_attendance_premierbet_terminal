import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'kiosk_admin_faces_page.dart';

class KioskColors {
  static const Color primary = Color(0xFF1D4ED8);
  static const Color primarySoftBg = Color(0xFFEFF6FF);
  static  Color background = Colors.grey.shade200;
  static const Color lightGray = Color(0xFFF1F5F9);
  static const Color outline = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF059669);
  static const Color danger = Color(0xFFDC2626);
  static const Color textHigh = Color(0xFF0F172A);
  static const Color textMid = Color(0xFF475569);
  static const Color textLow = Color(0xFF94A3B8);
}

double kioskScale(BuildContext context) => (MediaQuery.of(context).size.width / 390).clamp(0.8, 1.2);

TextStyle kioskTitle(BuildContext context) => TextStyle(
      fontSize: 24 * kioskScale(context),
      fontWeight: FontWeight.w900,
      color: KioskColors.textHigh,
      fontFamily: 'Poppins',
    );

TextStyle kioskSubtitle(BuildContext context) => TextStyle(
      fontSize: 18 * kioskScale(context),
      fontWeight: FontWeight.w700,
      color: KioskColors.textHigh,
      fontFamily: 'Poppins',
    );

TextStyle kioskBody(BuildContext context) => TextStyle(
      fontSize: 17 * kioskScale(context),
      fontWeight: FontWeight.w600,
      color: KioskColors.textHigh,
      fontFamily: 'Poppins',
    );

TextStyle kioskCaption(BuildContext context) => TextStyle(
      fontSize: 14 * kioskScale(context),
      fontWeight: FontWeight.w600,
      color: KioskColors.textLow,
      fontFamily: 'Poppins',
    );

class KioskScaffold extends StatelessWidget {
  const KioskScaffold({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: KioskColors.background,
        body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: child)),
      );
}

class KioskBrandHeader extends StatelessWidget {
  const KioskBrandHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return GestureDetector(
      onDoubleTap: () => Get.to(() => const KioskAdminFacesPage()),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46 * scale,
            height: 46 * scale,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [KioskColors.primary, Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: KioskColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                "S",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "SALAMA ATTENDANCE",
            style: TextStyle(
              fontSize: 20 * scale,
              fontWeight: FontWeight.w900,
              fontFamily: 'Poppins',
              color: KioskColors.textHigh,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class KioskScanFrame extends StatelessWidget {
  const KioskScanFrame({super.key, required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Center(
          child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            border: Border.all(color: KioskColors.primary.withValues(alpha: 0.2), width: 2),
            borderRadius: BorderRadius.circular(20)),
        child: const Stack(children: [
          _Corner(isTop: true, isLeft: true),
          _Corner(isTop: true, isLeft: false),
          _Corner(isTop: false, isLeft: true),
          _Corner(isTop: false, isLeft: false)
        ]),
      ));
}

class _Corner extends StatelessWidget {
  const _Corner({required this.isTop, required this.isLeft});
  final bool isTop, isLeft;
  @override
  Widget build(BuildContext context) => Positioned(
        top: isTop ? 0 : null,
        bottom: isTop ? null : 0,
        left: isLeft ? 0 : null,
        right: isLeft ? null : 0,
        child: SizedBox(
          width: 40,
          height: 40,
          child: CustomPaint(
            painter: _CornerPainter(isTop: isTop, isLeft: isLeft),
          ),
        ),
      );
}

class _CornerPainter extends CustomPainter {
  final bool isTop, isLeft;
  _CornerPainter({required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = KioskColors.primary
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const radius = 20.0;

    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, radius);
      path.arcToPoint(const Offset(radius, 0), radius: const Radius.circular(radius));
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width - radius, 0);
      path.arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius));
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - radius);
      path.arcToPoint(Offset(radius, size.height), radius: const Radius.circular(radius), clockwise: false);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height - radius);
      path.arcToPoint(Offset(size.width - radius, size.height), radius: const Radius.circular(radius));
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class KioskPrimaryButton extends StatelessWidget {
  const KioskPrimaryButton({super.key, required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      height: 76,
      child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 26),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, fontFamily: 'Poppins')),
          style: ElevatedButton.styleFrom(
              backgroundColor: KioskColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4)));
}

class KioskActionButton extends StatelessWidget {
  const KioskActionButton(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onPressed});
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      height: 104,
      child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 6),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(icon, size: 36)),
            const SizedBox(width: 24),
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
                  Text(subtitle, style: const TextStyle(fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.w600))
                ])
          ])));
}

class KioskOutlineButton extends StatelessWidget {
  const KioskOutlineButton({super.key, required this.label, required this.icon, this.height, required this.onPressed});
  final String label;
  final IconData icon;
  final double? height;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      height: height ?? 64,
      child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 24),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Poppins')),
          style: OutlinedButton.styleFrom(
              foregroundColor: KioskColors.textHigh,
              side: const BorderSide(color: KioskColors.outline, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))));
}

class KioskGhostButton extends StatelessWidget {
  const KioskGhostButton({super.key, required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: KioskColors.textMid),
      label: Text(label,
          style: const TextStyle(color: KioskColors.textMid, fontWeight: FontWeight.w700, fontFamily: 'Poppins')));
}

class KioskCard extends StatelessWidget {
  const KioskCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) => Container(
      padding: padding ?? const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))]),
      child: child);
}

class KioskBadge extends StatelessWidget {
  const KioskBadge({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: KioskColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: const TextStyle(
              color: KioskColors.success, fontWeight: FontWeight.w900, fontSize: 12, fontFamily: 'Poppins')));
}

class ScannerControl extends StatelessWidget {
  const ScannerControl({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 36, color: KioskColors.primary),
      style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))));
}

class CaptureAction extends StatelessWidget {
  const CaptureAction(
      {super.key,
      required this.icon,
      required this.label,
      required this.color,
      required this.onTap,
      this.isLarge = false});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLarge;
  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: EdgeInsets.all(isLarge ? 24 : 18),
              decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))]),
              child: Icon(icon, color: Colors.white, size: (isLarge ? 36 : 28) * scale)),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: KioskColors.textHigh, fontWeight: FontWeight.w800, fontFamily: 'Poppins', fontSize: 12))
        ]));
  }
}

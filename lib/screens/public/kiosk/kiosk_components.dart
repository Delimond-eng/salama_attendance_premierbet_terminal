import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'kiosk_admin_faces_page.dart';

class KioskColors {
  static const Color primary = Color(0xFF0F4ACF);
  static const Color primaryDark = Color(0xFF0B2D7A);
  static const Color accent = Color(0xFF0EA5E9);
  static const Color primarySoftBg = Color(0xFFEAF2FF);
  static const Color backgroundTop = Color(0xFFF6F9FF);
  static const Color backgroundBottom = Color(0xFFE8EEF9);
  static const Color background = backgroundBottom;
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF4F7FC);
  static const Color lightGray = Color(0xFFF1F5F9);
  static const Color outline = Color(0xFFD3DEEE);
  static const Color success = Color(0xFF0F9D74);
  static const Color danger = Color(0xFFE03131);
  static const Color textHigh = Color(0xFF0B1220);
  static const Color textMid = Color(0xFF4D5B78);
  static const Color textLow = Color(0xFF8A96AE);
}

double kioskScale(BuildContext context) =>
    (MediaQuery.sizeOf(context).width / 390).clamp(0.82, 1.2).toDouble();

TextStyle kioskTitle(BuildContext context) => TextStyle(
  fontSize: 28 * kioskScale(context),
  fontWeight: FontWeight.w800,
  color: KioskColors.textHigh,
  fontFamily: 'Ubuntu',
  letterSpacing: -0.2,
);

TextStyle kioskSubtitle(BuildContext context) => TextStyle(
  fontSize: 19 * kioskScale(context),
  fontWeight: FontWeight.w700,
  color: KioskColors.textHigh,
  fontFamily: 'Ubuntu',
  letterSpacing: 0.1,
);

TextStyle kioskBody(BuildContext context) => TextStyle(
  fontSize: 15 * kioskScale(context),
  fontWeight: FontWeight.w500,
  color: KioskColors.textMid,
  fontFamily: 'Ubuntu',
  height: 1.35,
);

TextStyle kioskCaption(BuildContext context) => TextStyle(
  fontSize: 13 * kioskScale(context),
  fontWeight: FontWeight.w600,
  color: KioskColors.textLow,
  fontFamily: 'Ubuntu',
  letterSpacing: 0.2,
);

class KioskScaffold extends StatelessWidget {
  const KioskScaffold({
    super.key,
    required this.child,
    this.padding,
    this.topSafeArea = true,
    this.bottomSafeArea = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool topSafeArea;
  final bool bottomSafeArea;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KioskColors.backgroundBottom,
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [KioskColors.backgroundTop, KioskColors.backgroundBottom],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -130,
            right: -100,
            child: _GlowBlob(size: 280, color: KioskColors.primarySoftBg),
          ),
          const Positioned(
            left: -120,
            bottom: -100,
            child: _GlowBlob(size: 240, color: KioskColors.surface),
          ),
          SafeArea(
            top: topSafeArea,
            bottom: bottomSafeArea,
            child: Padding(
              padding:
                  padding ??
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class KioskBrandHeader extends StatelessWidget {
  const KioskBrandHeader({
    super.key,
    this.blueMode = false,
    this.enableAdminShortcut = true,
  });

  final bool blueMode;
  final bool enableAdminShortcut;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    final headerBackground = blueMode
        ? Colors.white.withValues(alpha: 0.16)
        : KioskColors.surface.withValues(alpha: 0.78);
    final headerBorder = blueMode
        ? Colors.white.withValues(alpha: 0.28)
        : KioskColors.outline.withValues(alpha: 0.7);
    final headerShadow = blueMode
        ? Colors.black.withValues(alpha: 0.08)
        : KioskColors.primaryDark.withValues(alpha: 0.06);
    final titleColor = blueMode ? Colors.white : KioskColors.textHigh;
    final subtitleColor = blueMode
        ? Colors.white.withValues(alpha: 0.86)
        : KioskColors.textLow;

    return GestureDetector(
      onDoubleTap: enableAdminShortcut
          ? () => Get.to(() => const KioskAdminFacesPage())
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: headerBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: headerBorder),
          boxShadow: [
            BoxShadow(
              color: headerShadow,
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46 * scale,
              height: 46 * scale,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [KioskColors.primary, KioskColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: KioskColors.primary.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
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
                    fontFamily: 'Ubuntu',
                  ),
                ),
              ),
            ),
            SizedBox(width: 12 * scale),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SALAMA ATTENDANCE",
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Ubuntu',
                    color: titleColor,
                    letterSpacing: 0.7,
                  ),
                ),
                Text(
                  "Smart Kiosk",
                  style: kioskCaption(context).copyWith(
                    color: subtitleColor,
                    fontSize: 11 * scale,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
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
        color: KioskColors.surface.withValues(alpha: 0.02),
        border: Border.all(
          color: KioskColors.primary.withValues(alpha: 0.28),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Stack(
        children: [
          _Corner(isTop: true, isLeft: true),
          _Corner(isTop: true, isLeft: false),
          _Corner(isTop: false, isLeft: true),
          _Corner(isTop: false, isLeft: false),
        ],
      ),
    ),
  );
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
      ..color = KioskColors.accent
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const radius = 20.0;

    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, radius);
      path.arcToPoint(
        const Offset(radius, 0),
        radius: const Radius.circular(radius),
      );
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width - radius, 0);
      path.arcToPoint(
        Offset(size.width, radius),
        radius: const Radius.circular(radius),
      );
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - radius);
      path.arcToPoint(
        Offset(radius, size.height),
        radius: const Radius.circular(radius),
        clockwise: false,
      );
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height - radius);
      path.arcToPoint(
        Offset(size.width - radius, size.height),
        radius: const Radius.circular(radius),
      );
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class KioskPrimaryButton extends StatelessWidget {
  const KioskPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return SizedBox(
      width: double.infinity,
      height: 70 * scale,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24 * scale),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16 * scale,
            fontFamily: 'Ubuntu',
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: KioskColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22 * scale),
          ),
          elevation: 0,
          shadowColor: KioskColors.primaryDark.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class KioskActionButton extends StatelessWidget {
  const KioskActionButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return SizedBox(
      width: double.infinity,
      height: 102 * scale,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22 * scale),
          ),
          elevation: 0,
          shadowColor: color.withValues(alpha: 0.35),
        ),
        child: Row(
          children: [
            Container(
              width: 52 * scale,
              height: 52 * scale,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16 * scale),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.32),
                  width: 1.1,
                ),
              ),
              child: Icon(icon, size: 29 * scale),
            ),
            SizedBox(width: 18 * scale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 23 * scale,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Ubuntu',
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 5 * scale),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontFamily: 'Ubuntu',
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.95),
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
}

class KioskOutlineButton extends StatelessWidget {
  const KioskOutlineButton({
    super.key,
    required this.label,
    required this.icon,
    this.height,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final double? height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return SizedBox(
      width: double.infinity,
      height: (height ?? 64) * scale,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22 * scale),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15 * scale,
            fontFamily: 'Ubuntu',
            letterSpacing: 0.1,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: KioskColors.textHigh,
          backgroundColor: KioskColors.surface.withValues(alpha: 0.82),
          side: BorderSide(
            color: KioskColors.outline.withValues(alpha: 0.95),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20 * scale),
          ),
        ),
      ),
    );
  }
}

class KioskGhostButton extends StatelessWidget {
  const KioskGhostButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: KioskColors.textMid, size: 18 * scale),
      label: Text(
        label,
        style: TextStyle(
          color: KioskColors.textMid,
          fontWeight: FontWeight.w700,
          fontFamily: 'Ubuntu',
          fontSize: 13 * scale,
          letterSpacing: 0.2,
        ),
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 8),
      ),
    );
  }
}

class KioskCard extends StatelessWidget {
  const KioskCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: KioskColors.primarySoftBg,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: KioskColors.primary.withValues(alpha: 0.1),
          blurRadius: 40,
          offset: const Offset(0, 15),
        ),
      ],
      border: Border.all(
        color: KioskColors.primary.withValues(alpha: 0.1),
        width: 1.5,
      ),
    ),
    child: child,
  );
}

class KioskBadge extends StatelessWidget {
  const KioskBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 7 * scale,
      ),
      decoration: BoxDecoration(
        color: KioskColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: KioskColors.success.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: KioskColors.success,
          fontWeight: FontWeight.w800,
          fontSize: 11.5 * scale,
          fontFamily: 'Ubuntu',
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class ScannerControl extends StatelessWidget {
  const ScannerControl({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 28 * scale, color: KioskColors.primary),
      style: IconButton.styleFrom(
        backgroundColor: KioskColors.surface.withValues(alpha: 0.95),
        padding: EdgeInsets.all(14 * scale),
        side: BorderSide(color: KioskColors.outline.withValues(alpha: 0.85)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18 * scale),
        ),
      ),
    );
  }
}

class CaptureAction extends StatelessWidget {
  const CaptureAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLarge = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    final buttonSize = (isLarge ? 74 : 62) * scale;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: (isLarge ? 33 : 26) * scale,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            label,
            style: TextStyle(
              color: KioskColors.textMid,
              fontWeight: FontWeight.w700,
              fontFamily: 'Ubuntu',
              fontSize: 11.5 * scale,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

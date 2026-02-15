import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'kiosk_components.dart';

class KioskStartScreen extends StatelessWidget {
  const KioskStartScreen({super.key, this.onStart});

  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    final buttonWidth = 340 * scale;

    return KioskScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(alignment: Alignment.center, child: KioskBrandHeader()),
          SizedBox(height: 30 * scale),
          Text(
            "Terminal de Pointage",
            textAlign: TextAlign.center,
            style: kioskTitle(context).copyWith(fontSize: 32 * scale),
          ),
          SizedBox(height: 8 * scale),
          Text(
            "Scannez la station pour ouvrir votre session et demarrer les pointages.",
            textAlign: TextAlign.center,
            style: kioskBody(context),
          ),
          SizedBox(height: 16 * scale),
          const Align(
            alignment: Alignment.center,
            child: KioskBadge(label: "BIENVENUE"),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: buttonWidth,
              child: _StartScanCard(scale: scale, onTap: onStart),
            ),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14 * scale),
            child: Text(
              "Le terminal intelligent de pointage par reconnaissance faciale.",
              textAlign: TextAlign.center,
              style: kioskCaption(context).copyWith(
                color: KioskColors.textMid,
                fontSize: 13.5 * scale,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          SizedBox(height: 8 * scale),
        ],
      ),
    );
  }
}

class _StartScanCard extends StatelessWidget {
  const _StartScanCard({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(22 * scale),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KioskColors.primary, KioskColors.accent],
          ),
          borderRadius: BorderRadius.circular(28 * scale),
          boxShadow: [
            BoxShadow(
              color: KioskColors.primary.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 86 * scale,
              height: 86 * scale,
              padding: EdgeInsets.all(18 * scale),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(22 * scale),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.26),
                  width: 1.2,
                ),
              ),
              child: SvgPicture.asset(
                "assets/svgs/scan.svg",
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                placeholderBuilder: (context) => Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 38 * scale,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 18 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Scanner une station",
                    style: kioskSubtitle(
                      context,
                    ).copyWith(color: Colors.white, fontSize: 21 * scale),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    "Pointer pour entrer ou sortir en quelques secondes.",
                    style: kioskCaption(context).copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12 * scale,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 28 * scale,
            ),
          ],
        ),
      ),
    );
  }
}

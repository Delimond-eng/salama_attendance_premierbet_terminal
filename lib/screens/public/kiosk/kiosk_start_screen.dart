import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'kiosk_components.dart';

class KioskStartScreen extends StatelessWidget {
  const KioskStartScreen({super.key, this.onStart});
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return KioskScaffold(
      child: Column(
        children: [
          const KioskBrandHeader(),
          const Spacer(),
          // Impeccable Square Blue Soft Button
          GestureDetector(
            onTap: onStart,
            child: Container(
              width: 280 * scale,
              height: 280 * scale,
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120 * scale,
                    height: 120 * scale,
                    padding: EdgeInsets.all(24 * scale),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      "assets/svgs/scan.svg",
                      colorFilter: const ColorFilter.mode(KioskColors.primary, BlendMode.srcIn),
                      placeholderBuilder: (context) => const Icon(Icons.qr_code_scanner_rounded, size: 60, color: KioskColors.primary),
                    ),
                  ),
                  SizedBox(height: 28 * scale),
                  Text(
                    "SCANNER STATION",
                    textAlign: TextAlign.center,
                    style: kioskTitle(context).copyWith(
                      color: KioskColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 14.0
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Text(
              "Scannez le QR Code de la station pour commencer",
              textAlign: TextAlign.center,
              style: kioskBody(context).copyWith(color: KioskColors.textMid, fontSize: 12.0),
            ),
          ),
        ],
      ),
    );
  }
}

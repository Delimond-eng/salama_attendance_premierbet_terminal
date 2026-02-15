import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kiosk_components.dart';

const _kioskDarkStatusBarStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

class KioskSuccessScreen extends StatelessWidget {
  const KioskSuccessScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _kioskDarkStatusBarStyle,
      child: KioskScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Center(
              child: _StatusIcon(
                icon: Icons.check_rounded,
                color: KioskColors.success,
              ),
            ),
            SizedBox(height: 22 * scale),
            Text(
              "Opération terminée",
              textAlign: TextAlign.center,
              style: kioskTitle(context).copyWith(fontSize: 34 * scale),
            ),
            SizedBox(height: 9 * scale),
            Text(
              "Le pointage a été enregistré avec succes.",
              textAlign: TextAlign.center,
              style: kioskBody(context),
            ),
            SizedBox(height: 24 * scale),
            KioskCard(
              padding: EdgeInsets.all(22 * scale),
              child: Row(
                children: [
                  Container(
                    width: 50 * scale,
                    height: 50 * scale,
                    decoration: BoxDecoration(
                      color: KioskColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15 * scale),
                    ),
                    child: Icon(
                      Icons.verified_user_rounded,
                      color: KioskColors.success,
                      size: 28 * scale,
                    ),
                  ),
                  SizedBox(width: 14 * scale),
                  Expanded(
                    child: Text(
                      "Vous pouvez enchaîner avec un nouveau pointage.",
                      style: kioskCaption(
                        context,
                      ).copyWith(color: KioskColors.textMid),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            Center(
              child: KioskGhostButton(
                label: "Retour à l'accueil",
                icon: CupertinoIcons.house,
                onPressed: onDone,
              ),
            ),
            SizedBox(height: 8 * scale),
          ],
        ),
      ),
    );
  }
}

class KioskFailureScreen extends StatelessWidget {
  const KioskFailureScreen({
    super.key,
    required this.onRetry,
    required this.onCancel,
  });

  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _kioskDarkStatusBarStyle,
      child: KioskScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Center(
              child: _StatusIcon(
                icon: Icons.error_outline_rounded,
                color: KioskColors.danger,
              ),
            ),
            SizedBox(height: 22 * scale),
            Text(
              "Vérification echouée",
              textAlign: TextAlign.center,
              style: kioskTitle(context).copyWith(fontSize: 34 * scale),
            ),
            SizedBox(height: 10 * scale),
            Text(
              "Visage non reconnu. Vérifiez la luminosite puis réessayez.",
              textAlign: TextAlign.center,
              style: kioskBody(context),
            ),
            SizedBox(height: 24 * scale),
            KioskCard(
              padding: EdgeInsets.all(22 * scale),
              child: Row(
                children: [
                  Container(
                    width: 50 * scale,
                    height: 50 * scale,
                    decoration: BoxDecoration(
                      color: KioskColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15 * scale),
                    ),
                    child: Icon(
                      Icons.tips_and_updates_rounded,
                      color: KioskColors.danger,
                      size: 28 * scale,
                    ),
                  ),
                  SizedBox(width: 14 * scale),
                  Expanded(
                    child: Text(
                      "Essayez de récadrer le visage et d'éviter les contre-jours.",
                      style: kioskCaption(
                        context,
                      ).copyWith(color: KioskColors.textMid),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            KioskPrimaryButton(
              label: "Réessayer",
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
            SizedBox(height: 12 * scale),
            Center(
              child: KioskGhostButton(
                label: "Annuler",
                icon: Icons.close_rounded,
                onPressed: onCancel,
              ),
            ),
            SizedBox(height: 8 * scale),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return Container(
      width: 126 * scale,
      height: 126 * scale,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.28), width: 2),
      ),
      child: Icon(icon, size: 68 * scale, color: color),
    );
  }
}

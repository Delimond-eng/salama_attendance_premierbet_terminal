import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/global/controllers.dart';
import 'kiosk_components.dart';

class KioskAttendanceShellScreen extends StatelessWidget {
  const KioskAttendanceShellScreen({
    super.key,
    required this.onCheckAction,
    required this.onEnrollAction,
    required this.onBack,
  });
  final Function(String) onCheckAction;
  final VoidCallback onEnrollAction;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return KioskScaffold(
      child: Obx(() {
        final station = tagsController.activeStation.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KioskBrandHeader(),
            SizedBox(height: 32 * scale),
            KioskCard(
              padding: EdgeInsets.all(28 * scale),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: KioskColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: KioskColors.primary, size: 32),
                  ),
                  SizedBox(width: 20 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(station?['name'] ?? "STATION GOMBE", style: kioskTitle(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            KioskActionButton(
              title: "CHECK-IN",
              subtitle: "Pointage Entrée",
              icon: Icons.login_rounded,
              color: KioskColors.success,
              onPressed: () => onCheckAction("check-in"),
            ),
            SizedBox(height: 20 * scale),
            KioskActionButton(
              title: "CHECK-OUT",
              subtitle: "Pointage Sortie",
              icon: Icons.logout_rounded,
              color: KioskColors.danger,
              onPressed: () => onCheckAction("check-out"),
            ),
            const Spacer(),
            KioskOutlineButton(
              label: "Enrôler le visage d'un agent",
              icon: Icons.face_retouching_natural_rounded,
              height: 72 * scale,
              onPressed: onEnrollAction,
            ),
            SizedBox(height: 24 * scale),
            Center(
              child: KioskGhostButton(
                label: "RETOUR SCAN STATION",
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: onBack,
              ),
            ),
          ],
        );
      }),
    );
  }
}

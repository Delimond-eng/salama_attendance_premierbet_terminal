import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/global/controllers.dart';
import 'kiosk_components.dart';

class KioskSuccessScreen extends StatelessWidget {
  const KioskSuccessScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return KioskScaffold(
      child: Column(children: [

        const Spacer(),
        const Icon(Icons.check_circle_rounded, size: 120, color: KioskColors.success),
        SizedBox(height: 24 * scale),
        Text("SUCCÈS", style: kioskTitle(context).copyWith(fontSize: 32 * scale)),
        SizedBox(height: 32 * scale),
        KioskCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              CircleAvatar(
                  radius: 48 * scale,
                  backgroundColor: KioskColors.lightGray,
                  child: Icon(Icons.person, size: 48 * scale, color: KioskColors.textLow)),
              SizedBox(height: 20 * scale),
              const Text("OPÉRATION TERMINÉE",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Poppins')),
              const Text("L'action a été enregistrée avec succès.",
                  textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Poppins', color: KioskColors.textMid)),
            ],
          ),
        ),
        const Spacer(),
        KioskPrimaryButton(label: "RETOUR ACCUEIL", icon: Icons.arrow_back_outlined, onPressed: onDone),
        SizedBox(height: 24 * scale),
      ]),
    );
  }
}

class KioskFailureScreen extends StatelessWidget {
  const KioskFailureScreen({super.key, required this.onRetry, required this.onCancel});
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return KioskScaffold(
      child: Column(children: [
        const Spacer(),
        const Icon(Icons.warning_rounded, size: 120, color: KioskColors.danger),
        const SizedBox(height: 24),
        const Text("ÉCHEC", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text("Visage non reconnu. Veuillez réessayer.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: KioskColors.textMid, fontWeight: FontWeight.w600, fontFamily: 'Poppins'))),
        const Spacer(),
        KioskPrimaryButton(label: "RÉESSAYER", icon: Icons.refresh_rounded, onPressed: onRetry),
        const SizedBox(height: 16),
        KioskGhostButton(label: "ANNULER", icon: Icons.close_rounded, onPressed: onCancel),
      ]),
    );
  }
}

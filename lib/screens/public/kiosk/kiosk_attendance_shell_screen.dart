import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '/global/controllers.dart';
import '/kernel/services/native_face_service.dart';
import 'kiosk_admin_faces_page.dart';
import 'kiosk_components.dart';

class KioskAttendanceShellScreen extends StatefulWidget {
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
  State<KioskAttendanceShellScreen> createState() => _KioskAttendanceShellScreenState();
}

class _KioskAttendanceShellScreenState extends State<KioskAttendanceShellScreen> {
  final NativeFaceService _nativeService = NativeFaceService();
  bool _isKioskEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkKioskStatus();
  }

  Future<void> _checkKioskStatus() async {
    final enabled = await _nativeService.isMdmKioskEnabled();
    if (mounted) setState(() => _isKioskEnabled = enabled);
  }

  Future<void> _handleMdmToggle() async {
    final authenticated = await Get.dialog<bool>(
      const KioskAdminPasswordDialog(),
      barrierDismissible: true,
    );

    if (authenticated == true) {
      if (_isKioskEnabled) {
        await _nativeService.disableMdmKiosk();
      } else {
        await _nativeService.enableMdmKiosk();
      }
      await _checkKioskStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, 
        statusBarBrightness: Brightness.light,
      ),
      child: KioskScaffold(
        padding: EdgeInsets.zero,
        topSafeArea: false,
        child: Obx(() {
          final station = tagsController.activeStation.value;
          final stationName = (station?['name'] ?? 'Station principale').toString();
          final topInset = MediaQuery.paddingOf(context).top;
    
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                pinned: true,
                stretch: true,
                expandedHeight: topInset + 248 * scale,
                collapsedHeight: topInset + 56 * scale,
                toolbarHeight: 56 * scale,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: KioskColors.primaryDark,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _StationHeroSliverHeader(
                    scale: scale,
                    stationName: stationName,
                    topInset: topInset,
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24 * scale, 20 * scale, 24 * scale, 12 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      _PointerButton(
                        scale: scale,
                        onTap: () => widget.onCheckAction('pointage'),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: KioskOutlineButton(
                              label: "ENROLLER",
                              icon: Icons.face_retouching_natural_rounded,
                              height: 40,
                              onPressed: widget.onEnrollAction,
                            ),
                          ),
                          // Le bouton de désactivation/activation du mode Kiosque
                          // Visible pour quitter (désactiver) uniquement si actif, 
                          // ou visible pour activer si inactif.
                          if(_isKioskEnabled)...[
                            SizedBox(width: 12 * scale),
                            Expanded(
                              child: KioskOutlineButton(
                                label: _isKioskEnabled ? "QUITTER ADMIN" : "ACTIVER MDM",
                                icon: _isKioskEnabled ? CupertinoIcons.checkmark_shield : CupertinoIcons.lock_shield,
                                height: 40,
                                onPressed: _handleMdmToggle,
                              ),
                            ),
                          ]
                        ],
                      ),
                      SizedBox(height: 14 * scale),
                      Center(
                        child: KioskGhostButton(
                          label: 'Retour au scan station',
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: widget.onBack,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _PointerButton extends StatelessWidget {
  const _PointerButton({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback onTap;

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
            colors: [Colors.orange, Colors.deepOrange], // Orange vif
          ),
          borderRadius: BorderRadius.circular(28 * scale),
          boxShadow: [
            // Effet Avatar Glow
            BoxShadow(
              color: Colors.orange.withOpacity(0.4),
              blurRadius: 25,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.orange.withOpacity(0.2),
              blurRadius: 45,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 86 * scale,
              height: 86 * scale,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(22 * scale),
                border: Border.all(
                  color: Colors.white.withOpacity(0.26),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.face_retouching_natural_rounded,
                  size: 42 * scale,
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
                    "POINTER",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24 * scale,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Ubuntu',
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    "Identifiez-vous pour valider votre présence.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12 * scale,
                      fontFamily: 'Ubuntu',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }
}

class _StationHeroSliverHeader extends StatelessWidget {
  const _StationHeroSliverHeader({
    required this.scale,
    required this.stationName,
    required this.topInset,
  });

  final double scale;
  final String stationName;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KioskColors.primary, KioskColors.accent],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24 * scale, topInset + (10 * scale), 24 * scale, 24 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const KioskBrandHeader(blueMode: true),
            const Spacer(),
            Text(
              'STATION ${stationName.toUpperCase()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24 * scale,
                fontFamily: 'Ubuntu',
              ),
            ),
            const Spacer(),
            _WhitePill(
              scale: scale,
              icon: Icons.verified_rounded,
              label: 'Mode Terminal Actif',
            ),
          ],
        ),
      ),
    );
  }
}

class _WhitePill extends StatelessWidget {
  const _WhitePill({
    required this.scale,
    required this.icon,
    required this.label,
  });

  final double scale;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16 * scale),
          SizedBox(width: 8 * scale),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontFamily: 'Ubuntu',
                fontSize: 12 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

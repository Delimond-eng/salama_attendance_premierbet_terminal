import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '/global/controllers.dart';
import '/kernel/services/native_face_service.dart';
import 'kiosk_admin_faces_page.dart';
import 'kiosk_components.dart';
import 'kiosk_station_scan_screen.dart';

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

  Future<void> _showAdminAuth(VoidCallback onAuthenticated) async {
    final authenticated = await Get.dialog<bool>(
      const KioskAdminPasswordDialog(),
      barrierDismissible: true,
    );
    if (authenticated == true) onAuthenticated();
  }

  Future<void> _handleMdmToggle() async {
    _showAdminAuth(() async {
      if (_isKioskEnabled) {
        await _nativeService.disableMdmKiosk();
      } else {
        bool success = await _nativeService.enableMdmKiosk();
        if (!success) {
          Get.snackbar("Erreur MDM", "L'app n'est pas Device Owner.",
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      }
      await _checkKioskStatus();
    });
  }

  Future<void> _handleRescanStation() async {
    _showAdminAuth(() {
      Get.to(() => KioskStationScanScreen(
        isLatReq: true,
        onSuccess: () => Get.back(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, 
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/attendance.jpg', fit: BoxFit.cover),
            Container(color: KioskColors.primary.withOpacity(0.75)),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const KioskBrandHeader(blueMode: true),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 10 * scale),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32 * scale),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(32 * scale),
                              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                            ),
                            child: Obx(() {
                              final station = tagsController.activeStation.value;
                              final stationName = (station?['name'] ?? 'Station principale').toString();

                              return Column(
                                children: [
                                  const SizedBox(height: 20),
                                  _StationBadge(name: stationName, scale: scale),
                                  const Spacer(),
                                  _CircularPointerButton(
                                    scale: scale,
                                    onTap: () => widget.onCheckAction('pointage'),
                                  ),
                                  const Spacer(),
                                  _WhitePill(scale: scale, icon: Icons.verified_rounded, label: 'Mode Terminal Actif'),
                                  const SizedBox(height: 32),
                                  
                                  // BOUTONS ADMIN EN CIRCLE ET CENTRÉS
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _CircleAdminButton(
                                        icon: Icons.face_retouching_natural_rounded,
                                        label: "ENROLLER",
                                        onTap: () => _showAdminAuth(widget.onEnrollAction),
                                        scale: scale,
                                      ),
                                      const SizedBox(width: 20),
                                      _CircleAdminButton(
                                        icon: Icons.location_on_outlined,
                                        label: "STATION",
                                        onTap: _handleRescanStation,
                                        scale: scale,
                                      ),
                                      const SizedBox(width: 20),
                                      _CircleAdminButton(
                                        icon: _isKioskEnabled ? CupertinoIcons.shield_slash : CupertinoIcons.lock_shield,
                                        label: _isKioskEnabled ? "QUITTER" : "ACTIVER",
                                        color: _isKioskEnabled ? Colors.redAccent : Colors.orange,
                                        onTap: _handleMdmToggle,
                                        scale: scale,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 30),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _BackButton(onBack: widget.onBack, scale: scale),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAdminButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double scale;
  final Color color;

  const _CircleAdminButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scale,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56 * scale,
            height: 56 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24 * scale),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9 * scale, fontWeight: FontWeight.bold, fontFamily: 'Staatliches'),
        ),
      ],
    );
  }
}

// ... (Reste du code _StationBadge, _BackButton, _CircularPointerButton, _WhitePill identiques)
class _StationBadge extends StatelessWidget {
  final String name;
  final double scale;
  const _StationBadge({required this.name, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 12 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, color: Colors.white, size: 22 * scale),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              name.toUpperCase(),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18 * scale, fontFamily: 'Ubuntu', letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onBack;
  final double scale;
  const _BackButton({required this.onBack, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12 * scale),
      child: TextButton.icon(
        onPressed: onBack,
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white.withOpacity(0.7), size: 18 * scale),
        label: Text('Retour au scan station', style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700, fontFamily: 'Ubuntu', fontSize: 13 * scale)),
      ),
    );
  }
}

class _CircularPointerButton extends StatelessWidget {
  const _CircularPointerButton({required this.scale, required this.onTap});
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 180 * scale, height: 180 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 40 * scale, spreadRadius: 5 * scale),
                BoxShadow(color: Colors.deepOrange.withOpacity(0.2), blurRadius: 60 * scale, spreadRadius: 10 * scale),
              ],
            ),
          ),
          Container(
            width: 150 * scale, height: 150 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.orange, Colors.deepOrange]),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.face_retouching_natural_rounded, size: 50 * scale, color: Colors.white),
                const SizedBox(height: 8),
                Text("POINTER", style: TextStyle(color: Colors.white, fontSize: 16 * scale, fontWeight: FontWeight.w900, fontFamily: 'Ubuntu', letterSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhitePill extends StatelessWidget {
  const _WhitePill({required this.scale, required this.icon, required this.label});
  final double scale;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16 * scale),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Ubuntu', fontSize: 12 * scale)),
        ],
      ),
    );
  }
}

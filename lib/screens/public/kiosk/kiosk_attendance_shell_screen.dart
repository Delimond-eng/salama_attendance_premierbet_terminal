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
        await _nativeService.enableMdmKiosk();
      }
      await _checkKioskStatus();
    });
  }

  Future<void> _handleRescanStation() async {
    _showAdminAuth(() {
      Get.to(() => KioskStationScanScreen(
        isLatReq: true,
        onSuccess: (){
          Get.back();
        },
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
            Image.asset(
              'assets/images/attendance.jpg',
              fit: BoxFit.cover,
            ),
            Container(
              color: KioskColors.primary.withOpacity(0.75),
            ),
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
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1.5,
                              ),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(vertical: 20 * scale),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minHeight: constraints.maxHeight - (40 * scale)),
                                    child: IntrinsicHeight(
                                      child: Obx(() {
                                        final station = tagsController.activeStation.value;
                                        final stationName = (station?['name'] ?? 'Station principale').toString();

                                        return Column(
                                          children: [
                                            // STATION BOX
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20 * scale),
                                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.location_on_rounded, color: Colors.white, size: 18 * scale),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    stationName.toUpperCase(),
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 16 * scale,
                                                      fontFamily: 'Ubuntu',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            const Spacer(),

                                            _CircularPointerButton(
                                              scale: scale,
                                              onTap: () => widget.onCheckAction('pointage'),
                                            ),

                                            const Spacer(),
                                            
                                            _WhitePill(
                                              scale: scale,
                                              icon: Icons.verified_rounded,
                                              label: 'Mode Terminal Actif',
                                            ),
                                            
                                            const SizedBox(height: 30),

                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                _SmallGlassButton(
                                                  label: "ENROLLER",
                                                  icon: Icons.face_retouching_natural_rounded,
                                                  onPressed: () => _showAdminAuth(widget.onEnrollAction),
                                                  scale: scale,
                                                ),
                                                const SizedBox(width: 8),
                                                _SmallGlassButton(
                                                  label: "STATION",
                                                  icon: Icons.qr_code_scanner_rounded,
                                                  onPressed: _handleRescanStation,
                                                  scale: scale,
                                                ),
                                                if (_isKioskEnabled) ...[
                                                  const SizedBox(width: 8),
                                                  _SmallGlassButton(
                                                    label: "QUITTER",
                                                    icon: CupertinoIcons.lock_open_fill,
                                                    onPressed: _handleMdmToggle,
                                                    scale: scale,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                );
                              }
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextButton.icon(
                      onPressed: widget.onBack,
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white.withOpacity(0.7), size: 16 * scale),
                      label: Text(
                        'Retour au scan station',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Ubuntu',
                          fontSize: 12 * scale,
                        ),
                      ),
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
            width: 170 * scale,
            height: 170 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 30 * scale,
                  spreadRadius: 5 * scale,
                ),
              ],
            ),
          ),
          Container(
            width: 140 * scale,
            height: 140 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange, Colors.deepOrange],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.face_retouching_natural_rounded, size: 46 * scale, color: Colors.white),
                const SizedBox(height: 6),
                Text(
                  "POINTER",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Ubuntu',
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallGlassButton extends StatelessWidget {
  const _SmallGlassButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.scale,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12 * scale),
      child: Material(
        color: Colors.white.withOpacity(0.12),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 10 * scale),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16 * scale, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11 * scale,
                    fontFamily: 'Ubuntu',
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
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14 * scale),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFamily: 'Ubuntu',
              fontSize: 11 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

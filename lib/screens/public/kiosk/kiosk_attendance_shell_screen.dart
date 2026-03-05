import 'dart:ui';
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
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. BACKGROUND IMAGE
            Image.asset(
              'assets/images/attendance.jpg',
              fit: BoxFit.cover,
            ),

            // 2. PRIMARY COLOR OVERLAY
            Container(
              color: KioskColors.primary.withOpacity(0.75),
            ),

            // 3. CONTENT
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const KioskBrandHeader(blueMode: true),
                  const SizedBox(height: 20),
                  
                  // 4. GLASS CONTAINER
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 10 * scale),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32 * scale),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20 * scale),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(32 * scale),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1.5,
                              ),
                            ),
                            child: Obx(() {
                              final station = tagsController.activeStation.value;
                              final stationName = (station?['name'] ?? 'Station principale').toString();

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 32),
                                  // STATION NAME WITH LOCATION ICON (TOP OF GLASS)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.location_on_outlined, color: Colors.white.withOpacity(0.8), size: 22 * scale),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          stationName.toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 22 * scale,
                                            fontFamily: 'Ubuntu',
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height:20.0),
                                  // 6. TERMINAL STATUS PILL
                                  _WhitePill(
                                    scale: scale,
                                    icon: Icons.verified_rounded,
                                    label: 'Terminal de pointage',
                                  ),

                                  
                                  const Spacer(),

                                  // 5. CIRCULAR POINTER BUTTON (CENTER)
                                  _CircularPointerButton(
                                    scale: scale,
                                    onTap: () => widget.onCheckAction('pointage'),
                                  ),

                                  const Spacer(),
                                  


                                  // 7. ADMIN BUTTONS (Minimal Size & Centered)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _SmallGlassButton(
                                        label: "ENROLLER",
                                        icon: Icons.face_retouching_natural_rounded,
                                        onPressed: widget.onEnrollAction,
                                        scale: scale,
                                      ),
                                      if(_isKioskEnabled)...[
                                        const SizedBox(width: 12),
                                        _SmallGlassButton(
                                          label: _isKioskEnabled ? "QUITTER" : "MDM",
                                          icon: _isKioskEnabled ? CupertinoIcons.lock_open_fill : CupertinoIcons.lock_fill,
                                          onPressed: _handleMdmToggle,
                                          scale: scale,
                                        ),
                                      ]
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // 8. CORRECTION BOUTON RETOUR
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12 * scale),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: widget.onBack,
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white.withOpacity(0.7), size: 18 * scale),
                        label: Text(
                          'Retour au scan station',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Ubuntu',
                            fontSize: 13 * scale,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
          // GLOW EFFECT
          Container(
            width: 190 * scale,
            height: 190 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.4),
                  blurRadius: 40 * scale,
                  spreadRadius: 5 * scale,
                ),
                BoxShadow(
                  color: Colors.deepOrange.withOpacity(0.2),
                  blurRadius: 60 * scale,
                  spreadRadius: 10 * scale,
                ),
              ],
            ),
          ),
          // MAIN BUTTON
          Container(
            width: 180 * scale,
            height: 180 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange, Colors.deepOrange],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.face_retouching_natural_rounded, size: 50 * scale, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  "POINTER",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Ubuntu',
                    letterSpacing: 1.5,
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
      borderRadius: BorderRadius.circular(14 * scale),
      child: Material(
        color: Colors.white.withOpacity(0.12),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 12 * scale),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
              borderRadius: BorderRadius.circular(14 * scale),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18 * scale, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13 * scale,
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
        horizontal: 14 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16 * scale),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFamily: 'Ubuntu',
              fontSize: 12 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

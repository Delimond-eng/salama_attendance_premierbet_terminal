import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '/global/controllers.dart';
import '/kernel/services/api.dart';
import '/kernel/services/native_face_service.dart';
import 'kiosk_admin_faces_page.dart';
import 'kiosk_components.dart';
import 'kiosk_station_scan_screen.dart';

/// Palette d'accent dédiée à cet écran. Indépendante de [KioskColors]
/// pour ne pas impacter le reste du kiosque — à ajuster librement
/// (ex. par client via `_client`) si besoin d'une identité différente.
class _ShellPalette {
  static const Color accentStart = Color(0xFFFF8A3D);
  static const Color accentEnd = Color(0xFFE85D2C);
  static const Color success = Color(0xFF3DDC97);
  static const Color danger = Color(0xFFFF5C5C);
}

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

  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  static const List<String> _weekdays = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];
  static const List<String> _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  @override
  void initState() {
    super.initState();
    _checkKioskStatus();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String get _client {
    final url = Api.baseUrl.toLowerCase();
    if (url.contains('electrocool')) return 'electrocool';
    if (url.contains('premierbet')) return 'premierbet';
    if (url.contains('chanimetal')) return 'chanimetal';
    return 'default';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  String _formatDate(DateTime d) {
    final wd = _weekdays[d.weekday - 1];
    return '$wd ${d.day} ${_months[d.month - 1]}';
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

  Future<void> _toggleMdm() async {
    if (_isKioskEnabled) {
      await _nativeService.disableMdmKiosk();
    } else {
      final success = await _nativeService.enableMdmKiosk();
      if (!success) {
        Get.snackbar(
          "Erreur MDM",
          "L'app n'est pas Device Owner.",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
    await _checkKioskStatus();
  }

  void _openAdminMenu() {
    _showAdminAuth(() {
      Get.bottomSheet(
        _AdminActionsSheet(
          isKioskEnabled: _isKioskEnabled,
          onEnroll: () {
            Get.back();
            widget.onEnrollAction();
          },
          onRescanStation: () {
            Get.back();
            Get.to(() => KioskStationScanScreen(
              isLatReq: true,
              onSuccess: () => Get.back(),
            ));
          },
          onToggleMdm: () async {
            Get.back();
            await _toggleMdm();
          },
        ),
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
      );
    });
  }

  Future<void> _handleBack() async {
    if (_client == 'premierbet') {
      _showAdminAuth(widget.onBack);
    } else {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: KioskColors.primaryDark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/attendance.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
              // Dégradé directionnel : plus doux en haut, plus sombre en bas
              // pour une meilleure lisibilité et une ambiance plus sobre
              // qu'un simple aplat de couleur.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      KioskColors.primaryDark.withOpacity(0.55),
                      KioskColors.primary.withOpacity(0.80),
                      KioskColors.primaryDark.withOpacity(0.92),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: 16 * scale),
                    const KioskBrandHeader(blueMode: true),
                    SizedBox(height: 18 * scale),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22 * scale, vertical: 8 * scale),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28 * scale),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.055),
                                borderRadius: BorderRadius.circular(28 * scale),
                                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                              ),
                              child: Obx(() {
                                final station = tagsController.activeStation.value;
                                final stationName = (station?['name'] ?? 'Station principale').toString();

                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 18 * scale),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _StationChip(name: stationName, scale: scale),
                                          _AdminGearButton(
                                            scale: scale,
                                            kioskLocked: _isKioskEnabled,
                                            onTap: _openAdminMenu,
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      _LiveClock(
                                        time: _formatTime(_now),
                                        date: _formatDate(_now),
                                        scale: scale,
                                      ),
                                      SizedBox(height: 26 * scale),
                                      _PrimaryActionButton(
                                        scale: scale,
                                        onTap: () => widget.onCheckAction('pointage'),
                                      ),
                                      SizedBox(height: 18 * scale),
                                      Text(
                                        'Approchez votre visage de la caméra',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 12 * scale,
                                          fontFamily: 'Ubuntu',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      _KioskStatusPill(scale: scale, active: _isKioskEnabled),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _FooterBackButton(onBack: _handleBack, scale: scale),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton d'action principal ("POINTER") avec halo respirant animé,
/// retour haptique et effet d'enfoncement.
class _PrimaryActionButton extends StatefulWidget {
  const _PrimaryActionButton({required this.scale, required this.onTap});
  final double scale;
  final VoidCallback onTap;

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: SizedBox(
        width: 200 * scale,
        height: 200 * scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _breathController,
              builder: (context, child) {
                final t = _breathController.value;
                final ringScale = 1.0 + (t * 0.12);
                final ringOpacity = (0.35 - (t * 0.15)).clamp(0.0, 1.0);
                return Transform.scale(
                  scale: ringScale,
                  child: Container(
                    width: 170 * scale,
                    height: 170 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _ShellPalette.accentEnd.withOpacity(ringOpacity),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
            AnimatedScale(
              scale: _pressed ? 0.93 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: Container(
                width: 150 * scale,
                height: 150 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_ShellPalette.accentStart, _ShellPalette.accentEnd],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _ShellPalette.accentEnd.withOpacity(0.45),
                      blurRadius: 30 * scale,
                      spreadRadius: 2 * scale,
                      offset: Offset(0, 10 * scale),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face_retouching_natural_rounded, size: 46 * scale, color: Colors.white),
                    SizedBox(height: 8 * scale),
                    Text(
                      'POINTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15 * scale,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Ubuntu',
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationChip extends StatelessWidget {
  const _StationChip({required this.name, required this.scale});
  final String name;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6 * scale,
            height: 6 * scale,
            decoration: const BoxDecoration(color: _ShellPalette.success, shape: BoxShape.circle),
          ),
          SizedBox(width: 8 * scale),
          Flexible(
            child: Text(
              name.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w700,
                fontSize: 11.5 * scale,
                fontFamily: 'Ubuntu',
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminGearButton extends StatelessWidget {
  const _AdminGearButton({
    required this.scale,
    required this.onTap,
    required this.kioskLocked,
  });

  final double scale;
  final VoidCallback onTap;
  final bool kioskLocked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36 * scale,
        height: 36 * scale,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(CupertinoIcons.gear_alt, color: Colors.white.withOpacity(0.85), size: 17 * scale),
            ),
            if (kioskLocked)
              Positioned(
                right: 4 * scale,
                top: 4 * scale,
                child: Container(
                  width: 7 * scale,
                  height: 7 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ShellPalette.danger,
                    border: Border.all(color: Colors.black.withOpacity(0.3), width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveClock extends StatelessWidget {
  const _LiveClock({required this.time, required this.date, required this.scale});
  final String time;
  final String date;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          time,
          style: TextStyle(
            color: Colors.white,
            fontSize: 52 * scale,
            fontWeight: FontWeight.w300,
            fontFamily: 'Ubuntu',
            letterSpacing: 2,
            height: 1.0,
          ),
        ),
        SizedBox(height: 4 * scale),
        Text(
          date,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13 * scale,
            fontWeight: FontWeight.w500,
            fontFamily: 'Ubuntu',
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _KioskStatusPill extends StatelessWidget {
  const _KioskStatusPill({required this.scale, required this.active});
  final double scale;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: Colors.white.withOpacity(0.7), size: 13 * scale),
          SizedBox(width: 6 * scale),
          Text(
            active ? 'Mode kiosque verrouillé' : 'Terminal prêt',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
              fontFamily: 'Ubuntu',
              fontSize: 11 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterBackButton extends StatelessWidget {
  const _FooterBackButton({required this.onBack, required this.scale});
  final VoidCallback onBack;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14 * scale),
      child: TextButton.icon(
        onPressed: onBack,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withOpacity(0.55),
          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
        ),
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 14 * scale),
        label: Text(
          'Retour au scan station',
          style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Ubuntu', fontSize: 12.5 * scale),
        ),
      ),
    );
  }
}

/// Feuille modale regroupant les actions d'administration, affichée
/// après authentification (voir `_openAdminMenu`).
class _AdminActionsSheet extends StatelessWidget {
  const _AdminActionsSheet({
    required this.isKioskEnabled,
    required this.onEnroll,
    required this.onRescanStation,
    required this.onToggleMdm,
  });

  final bool isKioskEnabled;
  final VoidCallback onEnroll;
  final VoidCallback onRescanStation;
  final VoidCallback onToggleMdm;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: BoxDecoration(
            color: KioskColors.primaryDark.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Text(
                'Administration',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Ubuntu',
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 18),
              _AdminSheetTile(
                icon: Icons.face_retouching_natural_rounded,
                label: 'Enrôler un employé',
                onTap: onEnroll,
              ),
              const SizedBox(height: 10),
              _AdminSheetTile(
                icon: Icons.location_on_outlined,
                label: 'Rafraîchir la station',
                onTap: onRescanStation,
              ),
              const SizedBox(height: 10),
              _AdminSheetTile(
                icon: isKioskEnabled ? CupertinoIcons.shield_slash : CupertinoIcons.lock_shield,
                label: isKioskEnabled ? 'Quitter le mode kiosque' : 'Activer le mode kiosque',
                color: isKioskEnabled ? _ShellPalette.danger : _ShellPalette.accentEnd,
                onTap: onToggleMdm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSheetTile extends StatelessWidget {
  const _AdminSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Ubuntu',
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}


/*import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '/global/controllers.dart';
import '/kernel/services/api.dart';
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

  String get _client {
    final url = Api.baseUrl.toLowerCase();
    if (url.contains('electrocool')) return 'electrocool';
    if (url.contains('premierbet')) return 'premierbet';
    if (url.contains('chanimetal')) return 'chanimetal';
    return 'default';
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

  Future<void> _handleBack() async {
    if (_client == 'premierbet') {
      _showAdminAuth(widget.onBack);
    } else {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: KioskColors.primaryDark,
          systemNavigationBarIconBrightness: Brightness.light
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/attendance.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
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
                    _BackButton(onBack: _handleBack, scale: scale),
                  ],
                ),
              ),
            ],
          ),
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
        icon: Icon(Icons.arrow_back_outlined, color: Colors.white.withOpacity(0.7), size: 18 * scale),
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
*/

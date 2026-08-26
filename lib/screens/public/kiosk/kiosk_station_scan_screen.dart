import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '/kernel/services/api.dart';
import '/kernel/services/native_face_service.dart';
import '/global/controllers.dart';
import '/global/store.dart';
import '/kernel/services/http_manager.dart';
import 'kiosk_components.dart';

class KioskStationScanScreen extends StatefulWidget {
  const KioskStationScanScreen({super.key, this.isLatReq = false, required this.onSuccess});

  final bool isLatReq;
  final VoidCallback onSuccess;

  @override
  State<KioskStationScanScreen> createState() => _KioskStationScanScreenState();
}

class _KioskStationScanScreenState extends State<KioskStationScanScreen> with WidgetsBindingObserver {
  MobileScannerController controller = MobileScannerController();

  final NativeFaceService _nativeService = NativeFaceService();
  bool _hasScanned = false;
  bool _isLight = false;
  bool _isPermissionGranted = false;
  bool _isKioskEnabled = false;

  String get _client {
    final url = Api.baseUrl.toLowerCase();
    if (url.contains('electrocool')) return 'electrocool';
    if (url.contains('premierbet')) return 'premierbet';
    if (url.contains('chanimetal')) return 'chanimetal';
    return 'default';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _checkKioskStatus();
  }

  Future<void> _checkKioskStatus() async {
    final enabled = await _nativeService.isMdmKioskEnabled();
    if (mounted) setState(() => _isKioskEnabled = enabled);
  }

  Future<bool> _authenticate() async {
    final authenticated = await Get.dialog<bool>(
      const KioskAdminPasswordDialog(),
      barrierDismissible: true,
    );
    return authenticated == true;
  }

  Future<void> _showAdminAuth(VoidCallback onAuthenticated) async {
    if (await _authenticate()) onAuthenticated();
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

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _isPermissionGranted = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isPermissionGranted) {
      controller.start();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue == null) continue;

      try {
        final data = jsonDecode(barcode.rawValue!);
        if (data['type'] != 'station_pointage') continue;

        setState(() => _hasScanned = true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text('Identification de la station...', style: TextStyle(fontFamily: 'Ubuntu', fontWeight: FontWeight.w600))),
              ],
            ),
            backgroundColor: KioskColors.accent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 15),
          ),
        );

        await controller.stop();

        tagsController.setStation(data);
        final res = await HttpManager().identifyStation(getPosition: widget.isLatReq);

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (res == "success") {
          localStorage.write('active_station', data);
          widget.onSuccess(); 
        } else {
          setState(() => _hasScanned = false);
          await controller.start();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.toString(), style: const TextStyle(fontFamily: 'Ubuntu', fontWeight: FontWeight.w600)),
              backgroundColor: KioskColors.danger,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        break;
      } catch (_) {
        debugPrint("QR code invalide");
      }
    }
  }

  Future<void> _restartScan() async {
    setState(() => _hasScanned = false);
    await controller.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    final frameSize = 250 * scale;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        if (_client == 'premierbet') {
          final isAuth = await _authenticate();
          if (isAuth) {
            Get.back();
          }
        } else {
          Get.back();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
          statusBarColor: KioskColors.primaryDark,
          systemNavigationBarColor: KioskColors.primaryDark,
          systemNavigationBarIconBrightness: Brightness.light
        ),
        child: Scaffold(
          backgroundColor: Colors.indigo.shade400,
          body: Stack(
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 16 * scale),
                      const KioskBrandHeader(blueMode: true),
                      SizedBox(height: 30 * scale),
                      Text(
                        "Connexion de la station",
                        textAlign: TextAlign.center,
                        style: kioskTitle(context).copyWith(
                          fontSize: 30 * scale,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Text(
                                "Cadrez le QR code de votre station pour l'identifier",
                                textAlign: TextAlign.center,
                                style: kioskBody(context).copyWith(
                                  color: Colors.white70,
                                  fontSize: 12 * scale,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: Obx(() {
                          final isPageActive = tagsController.currentPageIndex.value == 1;
                          final isStandalone = widget.isLatReq;
                
                          if (!isPageActive && !isStandalone) return const SizedBox.shrink();
                          if (!_isPermissionGranted) return const Center(child: CircularProgressIndicator(color: Colors.white));
                
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(30 * scale),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: frameSize + 15 * scale,
                                height: frameSize + 15 * scale,
                                padding: EdgeInsets.all(2 * scale),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(30 * scale),
                                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22 * scale),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: SizedBox(
                                          width: frameSize, height: frameSize,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(22 * scale),
                                            child: MobileScanner(
                                              controller: controller,
                                              onDetect: _onDetect,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_hasScanned)
                                        Container(
                                          color: Colors.black.withOpacity(0.4),
                                          child: Center(
                                            child: IconButton(
                                              icon: Icon(Icons.refresh_rounded, size: 48 * scale, color: Colors.white),
                                              onPressed: _restartScan,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ScannerControl(
                            icon: _isLight ? Icons.flash_off_rounded : Icons.flash_on_rounded,
                            onTap: () {
                              controller.toggleTorch();
                              setState(() => _isLight = !_isLight);
                            },
                          ),
                          if (_hasScanned) ...[
                            SizedBox(width: 20 * scale),
                            ScannerControl(
                              icon: Icons.refresh_rounded,
                              onTap: _restartScan,
                              isPrimary: true,
                            ),
                          ],
                          if(_isKioskEnabled)...[
                            SizedBox(width: 20 * scale),
                            ScannerControl(
                              icon: _isKioskEnabled ? CupertinoIcons.shield_slash : CupertinoIcons.lock_shield,
                              onTap: _handleMdmToggle,
                            ),
                          ]
                
                        ],
                      ),
                      const Spacer(),
                      Text(
                        "Astuce: tenez le code à 20-30 cm de la caméra.",
                        textAlign: TextAlign.center,
                        style: kioskCaption(context).copyWith(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScannerControl extends StatelessWidget {
  const ScannerControl({super.key, required this.icon, required this.onTap, this.isPrimary = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22 * scale),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.all(16 * scale),
              decoration: BoxDecoration(
                color: isPrimary ? Colors.amber.withOpacity(0.25) : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(22 * scale),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 28 * scale,
                color: isPrimary ? Colors.amber.shade100 : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:terminal/kernel/services/native_face_service.dart';

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

    return KioskScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(alignment: Alignment.center, child: KioskBrandHeader()),
          SizedBox(height: 28 * scale),
          Text("Connexion de la station", textAlign: TextAlign.center, style: kioskTitle(context).copyWith(fontSize: 30 * scale)),
          SizedBox(height: 8 * scale),
          Text("Cadrez le QR code de votre station.", textAlign: TextAlign.center, style: kioskBody(context)),
          const Spacer(),
          Center(
            child: Obx(() {
              // OPTIMISATION: On affiche le scanner si on est sur la page 1 OU si on est en mode "LatReq" (via Get.to)
              final isPageActive = tagsController.currentPageIndex.value == 1;
              final isStandalone = widget.isLatReq;

              if (!isPageActive && !isStandalone) return const SizedBox.shrink();
              if (!_isPermissionGranted) return const Center(child: CircularProgressIndicator());

              return Container(
                width: 380 * scale, height: 380 * scale,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(22 * scale)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22 * scale),
                  child: Stack(
                    children: [
                      Center(
                        child: SizedBox(
                          width: frameSize, height: frameSize,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28 * scale),
                            child: MobileScanner(
                              controller: controller,
                              onDetect: _onDetect,
                            ),
                          ),
                        ),
                      ),
                      Center(child: KioskScanFrame(size: frameSize)),
                    ],
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
                SizedBox(width: 12 * scale),
                ScannerControl(icon: Icons.restart_alt_rounded, onTap: _restartScan),
              ],
              if(_isKioskEnabled)...[
                SizedBox(width: 12 * scale),
                ScannerControl(
                  icon: _isKioskEnabled ? CupertinoIcons.shield_slash : CupertinoIcons.lock_shield,
                  onTap: _handleMdmToggle,
                ),
              ]

            ],
          ),
          SizedBox(height: 10 * scale),
          Text("Astuce: tenez le code à 20-30 cm de la caméra.", textAlign: TextAlign.center, style: kioskCaption(context)),
        ],
      ),
    );
  }
}

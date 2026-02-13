import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '/global/controllers.dart';
import '/global/store.dart';
import '/kernel/services/http_manager.dart';
import 'kiosk_components.dart';

class KioskStationScanScreen extends StatefulWidget {
  const KioskStationScanScreen({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<KioskStationScanScreen> createState() => _KioskStationScanScreenState();
}

class _KioskStationScanScreenState extends State<KioskStationScanScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _hasScanned = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        try {
          final data = jsonDecode(barcode.rawValue!);
          if (data['type'] == 'station_pointage') {
            setState(() => _hasScanned = true);
            
            // Loader d'attente stylisé via SnackBar (comme demandé)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: const [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    SizedBox(width: 16),
                    Text('Vérification du code...', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  ],
                ),
                backgroundColor: KioskColors.primary,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                duration: const Duration(seconds: 15),
              ),
            );

            await controller.stop();

            tagsController.setStation(data);
            final http = HttpManager();
            final res = await http.identifyStation();
            
            ScaffoldMessenger.of(context).hideCurrentSnackBar();

            if (res == "success") {
              // Persister la station localement
              localStorage.write('active_station', data);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Station identifiée : ${data['name']}', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  backgroundColor: KioskColors.success,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
              widget.onSuccess();
            } else {
              setState(() => _hasScanned = false);
              await controller.start();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.toString(), style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  backgroundColor: KioskColors.danger,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            }
            break;
          }
        } catch (e) {
          debugPrint("QR Code non valide");
        }
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return KioskScaffold(
      child: Column(
        children: [
          const KioskBrandHeader(),
          SizedBox(height: 40 * scale),
          Text("Scanner la Station", style: kioskTitle(context)),
          const Spacer(),
          Center(
            child: Obx(() {
              if (tagsController.currentPageIndex.value != 1) return const SizedBox.shrink();
              return Container(
                width: 380 * scale,
                height: 380 * scale,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      MobileScanner(controller: controller, onDetect: _onDetect),
                      const KioskScanFrame(size: 280),
                    ],
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          ScannerControl(icon: Icons.flash_on_rounded, onTap: () => controller.toggleTorch()),
          SizedBox(height: 32 * scale),
        ],
      ),
    );
  }
}

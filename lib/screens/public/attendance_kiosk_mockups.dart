import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '/global/controllers.dart';
import '/global/store.dart';
import 'kiosk/kiosk_components.dart';
import 'kiosk/kiosk_start_screen.dart';
import 'kiosk/kiosk_station_scan_screen.dart';
import 'kiosk/kiosk_attendance_shell_screen.dart';
import 'kiosk/kiosk_face_scan_page.dart';
import 'kiosk/kiosk_enroll_page.dart';
import 'kiosk/kiosk_status_screens.dart';

class KioskMockupsGallery extends StatefulWidget {
  const KioskMockupsGallery({super.key});

  @override
  State<KioskMockupsGallery> createState() => _KioskMockupsGalleryState();
}

class _KioskMockupsGalleryState extends State<KioskMockupsGallery> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Check for saved station on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedStation = localStorage.read('active_station');
      if (savedStation != null) {
        tagsController.setStation(Map<String, dynamic>.from(savedStation));
        _pageController.jumpToPage(2);
        tagsController.setPage(2);
      }
    });
  }

  void _updatePage(int index) {
    tagsController.setPage(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 600),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Black icons
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => tagsController.setPage(index),
          children: [
            KioskStartScreen(onStart: () {
              // Si une station est déjà scannée, on va directement au Shell (Page 2)
              if (tagsController.activeStation.value != null) {
                _updatePage(2);
              } else {
                _updatePage(1);
              }
            }),
            KioskStationScanScreen(onSuccess: () => _updatePage(2)),
            KioskAttendanceShellScreen(
              onCheckAction: (type) {
                tagsController.setAttendanceType(type);
                Get.to(() => KioskFaceScanPage(
                  onSuccess: () => _updatePage(3),
                  onCancel: () => Get.back(),
                ));
              },
              onEnrollAction: () {
                tagsController.setAttendanceType("ENROLL");
                Get.to(() => KioskEnrollPage(
                  onSuccess: () => _updatePage(3),
                  onCancel: () => Get.back(),
                ));
              },
              onBack: () {
                tagsController.resetKiosk();
                localStorage.remove('active_station'); // Clear persistence on explicit back
                _updatePage(1);
              },
            ),
            KioskSuccessScreen(onDone: () {
              // Après succès, on revient au Shell (Page 2) si la station est gardée
              _updatePage(2);
            }),
            KioskFailureScreen(
              onRetry: () => Get.back(),
              onCancel: () {
                Get.back();
                _updatePage(2);
              },
            ),
          ],
        ),
      ),
    );
  }
}

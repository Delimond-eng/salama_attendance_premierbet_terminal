import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '/global/controllers.dart';
import '/global/store.dart';
import 'kiosk/kiosk_start_screen.dart';
import 'kiosk/kiosk_station_scan_screen.dart';
import 'kiosk/kiosk_attendance_shell_screen.dart';
import 'kiosk/kiosk_face_scan_page.dart';
import 'kiosk/kiosk_enroll_page.dart';
import 'kiosk/kiosk_status_screens.dart';
import 'kiosk/kiosk_components.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedStation = localStorage.read('active_station');
      if (savedStation != null) {
        tagsController.setStation(Map<String, dynamic>.from(savedStation));
        tagsController.setPage(2);
        _pageController.jumpToPage(2);
      }
    });
  }

  void _updatePage(int index) {
    tagsController.setPage(index); // Mise à jour immédiate de l'index global
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
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => tagsController.setPage(index),
          children: [
            KioskStartScreen(
              onStart: () {
                if (tagsController.activeStation.value != null) {
                  _updatePage(2);
                } else {
                  _updatePage(1);
                }
              },
            ),
            KioskStationScanScreen( 
              onSuccess: () => _updatePage(2),
            ),
            KioskAttendanceShellScreen(
              onCheckAction: (type) {
                tagsController.setAttendanceType(type);
                Get.to(() => KioskFaceScanPage(
                  onSuccess: () => _updatePage(3),
                  onCancel: () => Get.back(),
                ));
              },
              onEnrollAction: () async {
                final authenticated = await Get.dialog<bool>(
                  const KioskAdminPasswordDialog(),
                  barrierDismissible: true,
                );
                if (authenticated == true) {
                  tagsController.setAttendanceType("ENROLL");
                  Get.to(() => KioskEnrollPage(
                    onSuccess: () => _updatePage(3),
                    onCancel: () => Get.back(),
                  ));
                }
              },
              onBack: () {
                tagsController.resetKiosk();
                localStorage.remove('active_station');
                _updatePage(1);
              },
            ),
            KioskSuccessScreen(onDone: () => _updatePage(2)),
            KioskFailureScreen(
              onRetry: () => Get.back(),
              onCancel: () { Get.back(); _updatePage(2); },
            ),
          ],
        ),
      ),
    );
  }
}

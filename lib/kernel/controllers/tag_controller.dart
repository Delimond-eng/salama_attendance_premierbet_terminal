import 'dart:async';
import 'dart:io';

import '/kernel/models/area.dart';
import '/kernel/models/user.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class TagsController extends GetxController {
  static TagsController instance = Get.find();

  // Kiosk / Attendance State
  var activeStation = Rxn<Map<String, dynamic>>();
  var attendanceType = "".obs; // "CHECK-IN", "CHECK-OUT", "ENROLL"
  var currentPageIndex = 0.obs;
  
  var scannedArea = Area().obs;
  var scannedSite = Site().obs;
  var isQrcodeScanned = false.obs;
  var patrolId = 0.obs;
  var isLoading = false.obs;
  var isScanningModalOpen = false.obs;
  var mediaFile = Rx<File?>(null);
  var face = Rx<XFile?>(null);
  var faceResult = "".obs;
  var isFlashOn = false.obs;
  var cameraIndex = 1.obs; // 1 = Front, 0 = Back
  var planningId = "".obs;

  void resetKiosk() {
    activeStation.value = null;
    attendanceType.value = "";
    face.value = null;
    cameraIndex.value = 1;
    currentPageIndex.value = 0;
  }

  void setStation(Map<String, dynamic> data) {
    activeStation.value = data;
  }

  void setAttendanceType(String type) {
    attendanceType.value = type;
  }
  
  void setPage(int index) {
    currentPageIndex.value = index;
  }
}

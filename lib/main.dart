import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '/constants/styles.dart';
import '/kernel/application.dart';
import '/kernel/controllers/tag_controller.dart';
import '/kernel/services/sync_service.dart';
import 'kernel/controllers/face_recognition_controller.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialiser Firebase pour cet isolate
  await Firebase.initializeApp();
  
  // Initialiser GetStorage car DeviceService peut l'utiliser
  await GetStorage.init();

  // Traiter la synchronisation biométrique en arrière-plan (SANS UI/EasyLoading)
  final syncService = SyncService();
  await syncService.handleNotification(message, silent: true);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Forcer le mode portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await GetStorage.init();
  
  Get.put(TagsController());
  Get.put(FaceRecognitionController());
  
  configEasyLoading();
  
  // Initialiser le service de synchronisation
  SyncService().init();

  runApp(const Application());
}

void configEasyLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..loadingStyle = EasyLoadingStyle.custom
    ..radius = 14.0
    ..backgroundColor = Colors.black
    ..textColor = Colors.white
    ..indicatorColor = Colors.white
    ..maskColor = primaryMaterialColor.shade300.withOpacity(0.5)
    ..userInteractions = true;
}

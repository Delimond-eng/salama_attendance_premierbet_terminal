import 'dart:convert';
import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '/kernel/models/face.dart';
import '/kernel/services/api.dart';
import '/kernel/services/database_helper.dart';
import '/kernel/services/device_service.dart';
import '/kernel/controllers/face_recognition_controller.dart';
import '/kernel/services/ota_service.dart';
import 'package:get/get.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    await _registerDevice();

    FirebaseMessaging.onMessage.listen((message) {
      _logFcmMessage(message, "FOREGROUND");
      handleNotification(message, silent: false);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _logFcmMessage(message, "OPENED_APP");
      handleNotification(message, silent: false);
    });
  }

  void _logFcmMessage(RemoteMessage message, String context) {
    dev.log("🔔 FCM RECEIVED [$context]");
    dev.log("   Data: ${message.data}");
  }

  Future<void> _registerDevice() async {
    final token = await DeviceService.getFcmToken();
    final deviceId = await DeviceService.getDeviceId();
    final deviceName = await DeviceService.getDeviceName();
    if (token == null) return;

    await Api.request(
      method: 'post',
      url: 'devices/register',
      body: {
        'imei': deviceId,
        'firebase_token': token,
        'platform': DeviceService.getPlatform(),
        'device_name': deviceName,
      },
    );
  }

  Future<void> handleNotification(RemoteMessage message, {bool silent = true}) async {
    final String? type = message.data['type'];

    // 1. Gestion de la mise à jour OTA
    if (type == 'update') {
      final String? url = message.data['url'];
      if (url != null && url.isNotEmpty) {
        await OtaService().updateApp(url);
      }
      return;
    }

    // 2. Gestion des synchronisations biométriques
    final dynamic rawMatricules = message.data['matricules'];
    if (rawMatricules == null) return;
    
    List<String> matricules = [];
    try {
      if (rawMatricules is List) {
        matricules = List<String>.from(rawMatricules);
      } else if (rawMatricules is String) {
        matricules = List<String>.from(jsonDecode(rawMatricules));
      }
    } catch (e) {
      dev.log("❌ Erreur parsing matricules FCM: $e");
      return;
    }

    if (matricules.isEmpty) return;

    if (type == 'biometric_sync') {
      await syncMatricules(matricules, silent: silent);
    } 
    else if (type == 'biometric_delete') {
      await deleteMatricules(matricules, silent: silent);
    }
  }

  Future<void> deleteMatricules(List<String> matricules, {bool silent = true}) async {
    try {
      if (!silent) EasyLoading.show(status: 'Suppression biométrique...');
      
      for (var matricule in matricules) {
        await _dbHelper.deleteFace(matricule);
      }

      if (Get.isRegistered<FaceRecognitionController>()) {
        await FaceRecognitionController.instance.reloadTemplates();
      }

      if (!silent) EasyLoading.showSuccess('${matricules.length} agents supprimés');
    } catch (e) {
      if (!silent) EasyLoading.showError('Erreur de suppression');
    }
  }

  Future<void> syncMatricules(List<String> matricules, {bool silent = true}) async {
    try {
      if (!silent) EasyLoading.show(status: 'Synchronisation biométrique...');

      final response = await Api.request(
        method: 'post',
        url: 'biometrics/by-matricules',
        body: {'matricules': matricules},
      );

      if (response != null && (response['status'] == 'success' || response['data'] != null)) {
        List data = response['data'] ?? [];
        
        for (var item in data) {
          List<double> embedding;
          var rawEmb = item['embedding'];
          if (rawEmb is String) {
            embedding = List<double>.from(jsonDecode(rawEmb).map((e) => e.toDouble()));
          } else {
            embedding = List<double>.from(rawEmb.map((e) => e.toDouble()));
          }

          final face = FacePicture(
            matricule: item['matricule'],
            name: item['name'] ?? item['fullname'] ?? item['matricule'],
            embedding: embedding,
          );
          
          await _dbHelper.deleteFace(face.matricule);
          await _dbHelper.insertFace(face);
        }
        
        if (Get.isRegistered<FaceRecognitionController>()) {
          await FaceRecognitionController.instance.reloadTemplates();
        }

        if (!silent) EasyLoading.showSuccess('${data.length} agents synchronisés');
      } else {
        if (!silent) EasyLoading.showError('Échec de la synchronisation');
      }
    } catch (e) {
      if (!silent) EasyLoading.showError('Erreur de connexion');
    }
  }
}

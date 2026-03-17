import 'dart:convert';
import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '/kernel/models/face.dart';
import '/kernel/services/api.dart';
import '/kernel/services/database_helper.dart';
import '/kernel/services/device_service.dart';
import '/kernel/controllers/face_recognition_controller.dart';
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
      _handleNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _logFcmMessage(message, "OPENED_APP");
      _handleNotification(message);
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

  void _handleNotification(RemoteMessage message) {
    if (message.data['type'] == 'biometric_sync') {
      try {
        dynamic rawMatricules = message.data['matricules'];
        List<String> matricules = [];
        if (rawMatricules is List) {
          matricules = List<String>.from(rawMatricules);
        } else if (rawMatricules is String) {
          matricules = List<String>.from(jsonDecode(rawMatricules));
        }

        if (matricules.isNotEmpty) {
          syncMatricules(matricules);
        }
      } catch (e) {
        dev.log("❌ Erreur parsing FCM: $e");
      }
    }
  }

  Future<void> syncMatricules(List<String> matricules) async {
    try {
      EasyLoading.show(status: 'Synchronisation biométrique...');

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
            name: item['matricule'],
            embedding: embedding,
          );
          
          await _dbHelper.deleteFace(face.matricule);
          await _dbHelper.insertFace(face);
        }
        
        // CRUCIAL: Recharger les templates en mémoire pour la reconnaissance
        if (Get.isRegistered<FaceRecognitionController>()) {
          await FaceRecognitionController.instance.reloadTemplates();
        }

        EasyLoading.showSuccess('${data.length} agents synchronisés');
      } else {
        EasyLoading.showError('Échec de la synchronisation');
      }
    } catch (e) {
      dev.log("❌ Sync error: $e");
      EasyLoading.showError('Erreur de connexion');
    }
  }
}

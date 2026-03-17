import 'dart:convert';
import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '/kernel/models/face.dart';
import '/kernel/services/api.dart';
import '/kernel/services/database_helper.dart';
import '/kernel/services/device_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Initialise Firebase Messaging et enregistre le terminal
  Future<void> init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Enregistrer le terminal au backend
    await _registerDevice();

    // Écouter les messages en premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logFcmMessage(message, "FOREGROUND");
      _handleNotification(message);
    });

    // Écouter si l'app est ouverte via une notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logFcmMessage(message, "OPENED_APP");
      _handleNotification(message);
    });
  }

  /// Log les notifications FCM reçues
  void _logFcmMessage(RemoteMessage message, String context) {
    dev.log("🔔 FCM RECEIVED [$context]");
    dev.log("   Title: ${message.notification?.title}");
    dev.log("   Body: ${message.notification?.body}");
    dev.log("   Data: ${message.data}");
  }

  /// Enregistre l'Identifiant et le Token FCM au backend
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

  /// Traite la notification reçue
  void _handleNotification(RemoteMessage message) {
    if (message.data['type'] == 'biometric_sync') {
      List<String> matricules = [];
      if (message.data['matricules'] is List) {
        matricules = List<String>.from(message.data['matricules']);
      } else if (message.data['matricules'] is String) {
        // Au cas où c'est envoyé en chaîne JSON
        try {

          matricules = List<String>.from(jsonDecode(message.data['matricules']));
        } catch (_) {}
      }

      if (matricules.isNotEmpty) {
        syncMatricules(matricules);
      }
    }
  }

  /// Télécharge et sauvegarde les embeddings
  Future<void> syncMatricules(List<String> matricules) async {
    try {
      EasyLoading.show(status: 'Synchronisation biométrique...');

      final response = await Api.request(
        method: 'post',
        url: 'biometrics/by-matricules',
        body: {'matricules': matricules},
      );

      if (response != null && response['status'] == 'success') {
        List data = response['data'];
        
        for (var item in data) {
          final face = FacePicture(
            matricule: item['matricule'],
            name: item['matricule'],
            embedding: List<double>.from(item['embedding'].map((e) => e.toDouble())),
          );
          
          await _dbHelper.deleteFace(face.matricule);
          await _dbHelper.insertFace(face);
        }
        
        EasyLoading.showSuccess('${data.length} agents synchronisés');
      } else {
        EasyLoading.showError('Échec de la synchronisation');
      }
    } catch (e) {
      EasyLoading.showError('Erreur: $e');
    }
  }
}

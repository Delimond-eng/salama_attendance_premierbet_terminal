import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static final GetStorage _storage = GetStorage();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Récupère un identifiant unique stable (Compatible Android 11+)
  static Future<String> getDeviceId() async {
    String? storedId = _storage.read('device_unique_id');
    if (storedId != null) return storedId;

    String finalId = "";
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        // L'ID Android est stable et ne nécessite pas de permissions sensibles
        finalId = androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        finalId = iosInfo.identifierForVendor ?? const Uuid().v4();
      } else {
        finalId = const Uuid().v4();
      }
    } catch (e) {
      finalId = const Uuid().v4();
    }

    await _storage.write('device_unique_id', finalId);
    return finalId;
  }

  /// Récupère le nom du modèle de l'appareil
  static Future<String> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo info = await _deviceInfo.androidInfo;
        return "${info.brand} ${info.model}";
      } else if (Platform.isIOS) {
        IosDeviceInfo info = await _deviceInfo.iosInfo;
        return info.name;
      }
    } catch (_) {}
    return "Terminal Inconnu";
  }

  /// Récupère le token Firebase
  static Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      return null;
    }
  }

  /// Retourne le nom de la plateforme
  static String getPlatform() {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    return "unknown";
  }
}

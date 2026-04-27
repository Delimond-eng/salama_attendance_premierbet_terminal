import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ota_update/ota_update.dart';

class OtaService {
  static final OtaService instance = OtaService._init();
  OtaService._init();
  factory OtaService() => instance;

  bool _isUpdating = false;

  Future<void> updateApp(String url) async {
    if (_isUpdating) return;
    _isUpdating = true;

    // Configuration locale pour un loader propre et discret
    EasyLoading.instance
      ..indicatorType = EasyLoadingIndicatorType.ring
      ..loadingStyle = EasyLoadingStyle.custom
      ..indicatorSize = 45.0
      ..radius = 10.0
      ..backgroundColor = Colors.black.withOpacity(0.8)
      ..indicatorColor = Colors.white
      ..textColor = Colors.white
      ..maskColor = Colors.transparent
      ..userInteractions = false
      ..dismissOnTap = false;

    // 1. Afficher le loader immédiatement (sans masque gris plein écran)
    EasyLoading.show(
      status: 'Initialisation...',
      maskType: EasyLoadingMaskType.none,
    );

    try {
      if (Platform.isAndroid) {
        var status = await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          EasyLoading.showInfo('Veuillez autoriser l\'installation');
          await Future.delayed(const Duration(seconds: 2));
          
          status = await Permission.requestInstallPackages.request();
          if (!status.isGranted) {
            EasyLoading.showError('Permission refusée');
            _isUpdating = false;
            return;
          }
          EasyLoading.show(status: 'Préparation...', maskType: EasyLoadingMaskType.none);
        }
      }

      EasyLoading.show(status: 'Connexion...', maskType: EasyLoadingMaskType.none);

      // 2. Exécution de la mise à jour
      OtaUpdate().execute(
        url,
        destinationFilename: 'terminal_update.apk',
      ).listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              EasyLoading.showProgress(
                (double.tryParse(event.value ?? '0') ?? 0) / 100,
                status: 'Téléchargement : ${event.value}%',
                maskType: EasyLoadingMaskType.none,
              );
              break;
            case OtaStatus.INSTALLING:
              EasyLoading.showSuccess('Installation en cours...');
              _isUpdating = false;
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              EasyLoading.showError('Mise à jour déjà en cours');
              _isUpdating = false;
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              EasyLoading.showError('Permission refusée');
              _isUpdating = false;
              break;
            case OtaStatus.INTERNAL_ERROR:
              EasyLoading.showError('Erreur interne (OTA)');
              _isUpdating = false;
              break;
            case OtaStatus.DOWNLOAD_ERROR:
              EasyLoading.showError('Erreur de téléchargement');
              _isUpdating = false;
              break;
            default:
              break;
          }
        },
        onError: (e) {
          EasyLoading.showError('Erreur : $e');
          _isUpdating = false;
        },
      );
    } catch (e) {
      EasyLoading.showError('Erreur système');
      _isUpdating = false;
    }
  }
}

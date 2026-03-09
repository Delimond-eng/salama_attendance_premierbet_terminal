import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';

import '/global/controllers.dart';
import '/kernel/services/api.dart';
import '/kernel/services/native_face_service.dart';

class HttpManager {
  final NativeFaceService _nativeService = NativeFaceService();

  String _extractErrorMessage(dynamic response) {
    if (response == null) return "Le serveur n'a renvoyé aucune réponse.";
    if (response is Map) {
      if (response.containsKey("errors")) {
        var err = response["errors"];
        if (err is List && err.isNotEmpty) return err[0].toString();
        if (err is Map && err.isNotEmpty) {
          var firstVal = err.values.first;
          return firstVal is List ? firstVal[0].toString() : firstVal.toString();
        }
        return err.toString();
      }
      if (response.containsKey("message")) return response["message"].toString();
    }
    return "Une erreur inconnue est survenue.";
  }

  Future<String> _getLatlng() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return "0.0,0.0";

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return "0.0,0.0";
      }
      
      if (permission == LocationPermission.deniedForever) return "0.0,0.0";

      // On ajoute un timeout de 5s pour ne pas bloquer l'UI
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5)
      );
      return "${position.latitude},${position.longitude}";
    } catch (e) {
      return "0.0,0.0";
    }
  }

  Future<dynamic> enrollAgent(String matricule) async {
    try {
      if (tagsController.face.value == null) return "Aucune photo capturée.";
      
      var data = {"matricule": matricule};
      var response = await Api.request(
        url: "agent.enroll",
        method: "post",
        files: {"photo": File(tagsController.face.value!.path)},
        body: data,
      );
      
      if (response != null && response is Map) {
        if (response.containsKey("errors")) {
          String msg = _extractErrorMessage(response);
          EasyLoading.showError(msg);
          return null;
        }
        return response;
      }
      return {"status": "error", "message": "Réponse invalide"};
    } catch (e) {
      return {"status": "error", "message": e.toString()};
    }
  }

  Future<dynamic> identifyStation({bool getPosition = false}) async {
    try {
      var stationId = tagsController.activeStation.value?['id'];
      
      // On ne récupère la position QUE si demandé (évite le lag au premier scan)
      String latlng = "0.0,0.0";
      if (getPosition) {
        latlng = await _getLatlng();
      }

      var data = {
        "station_id": stationId,
        "latlng": latlng
      };
      
      var response = await Api.request(
        url: "station.scan",
        method: "post",
        body: data,
      );
      if (response != null && response is Map) {
        if (response.containsKey("errors")) {
          String msg = _extractErrorMessage(response);
          EasyLoading.showError(msg);
          return msg;
        }
        return "success";
      }
      return _extractErrorMessage(response);
    } catch (e) {
      return "Échec de traitement de la requête !";
    }
  }

  Future<dynamic> checkPresence({required String key}) async {
    try {
      if (tagsController.face.value == null) return "Photo de pointage manquante.";
      
      String formattedKey = key.toLowerCase().replaceAll(" ", "-");
      final latlng = await _getLatlng();

      Map<String, dynamic> data = {
        "matricule": tagsController.faceResult.value,
        "station_id": tagsController.activeStation.value?['id'],
        "coordonnees": latlng,
        "key": formattedKey,
      };

      var response = await Api.request(
        url: "agent.punch",
        method: "post",
        body: data,
        files: {'photo': File(tagsController.face.value!.path)},
      );

      if (response != null && response is Map) {
        if (response.containsKey("errors")) {
          String msg = _extractErrorMessage(response);
          EasyLoading.showError(msg);
          return msg;
        }
        return "success";
      }
      return "success";
    } catch (e) {
      return "Échec de traitement de la requête biométrique.";
    }
  }
}

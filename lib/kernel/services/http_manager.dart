import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';

import '/global/controllers.dart';
import '/kernel/controllers/face_recognition_controller.dart';
import '/kernel/models/face.dart';
import '/kernel/services/api.dart';
import '/kernel/services/database_helper.dart';
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

  Future<String?> _getLatlng() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      
      if (permission == LocationPermission.deniedForever) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5)
      );
      return "${position.latitude},${position.longitude}";
    } catch (e) {
      return null;
    }
  }

  /// Enrôlement consolidé : Calcule la moyenne des 3 embeddings pour une signature unique
  Future<dynamic> enrollAgent(String matricule, {List<XFile>? capturedImages}) async {
    try {
      final List<XFile> images = (capturedImages != null && capturedImages.isNotEmpty) 
          ? capturedImages 
          : (tagsController.face.value != null ? [tagsController.face.value!] : []);

      if (images.isEmpty) return "Aucune photo capturée.";
      
      EasyLoading.show(status: 'Analyse biométrique...');
      
      List<List<double>> embeddings = [];
      for (var img in images) {
        final List<double>? e = await FaceRecognitionController.instance.getEmbedding(img);
        if (e != null) embeddings.add(e);
      }

      if (embeddings.isEmpty) {
        EasyLoading.showError("Échec de l'analyse faciale.");
        return null;
      }

      // Calcul de l'embedding moyen (signature consolidée)
      int size = embeddings[0].length;
      List<double> meanEmbedding = List.filled(size, 0.0);
      for (var e in embeddings) {
        for (int i = 0; i < size; i++) {
          meanEmbedding[i] += e[i];
        }
      }
      for (int i = 0; i < size; i++) {
        meanEmbedding[i] /= embeddings.length;
      }

      var data = {
        "matricule": matricule,
        "embedding": jsonEncode(meanEmbedding),
        "model_version": "facenet_v1",
        "quality_score": embeddings.length / images.length,
      };

      EasyLoading.show(status: 'Envoi au serveur...');
      var response = await Api.request(
        url: "agent.enroll",
        method: "post",
        files: {"photo": File(images.first.path)},
        body: data,
      );
      
      if (response != null && response is Map && response["status"] == "success") {
        // Optionnel : Sauvegarder localement l'embedding MOYEN pour cohérence totale
        final agentData = response["result"] as Map?;
        final String? agentName = agentData != null ? agentData["fullname"] : null;
        
        final face = FacePicture(
          matricule: matricule,
          name: agentName ?? matricule,
          embedding: meanEmbedding,
        );
        
        await DatabaseHelper().deleteFace(matricule);
        await DatabaseHelper().insertFace(face);
        await FaceRecognitionController.instance.reloadTemplates();
        
        EasyLoading.showSuccess("Enrôlement réussi");
        return response;
      }
      
      EasyLoading.dismiss();
      String error = _extractErrorMessage(response);
      EasyLoading.showError(error);
      return response;
    } catch (e) {
      EasyLoading.dismiss();
      return {"status": "error", "message": e.toString()};
    }
  }

  Future<dynamic> identifyStation({bool getPosition = false}) async {
    try {
      var stationId = tagsController.activeStation.value?['id'];
      String? latlng;
      if (getPosition) latlng = await _getLatlng();

      var data = {"station_id": stationId, "latlng": latlng};
      var response = await Api.request(url: "station.scan", method: "post", body: data);
      
      if (response != null && response is Map) {
        if (response.containsKey("errors")) {
          EasyLoading.showError(_extractErrorMessage(response));
          return null;
        }
        return "success";
      }
      return _extractErrorMessage(response);
    } catch (e) {
      return "Erreur station";
    }
  }

  Future<dynamic> checkPresence({required String key}) async {
    try {
      if (tagsController.face.value == null) return "Photo manquante.";
      final latlng = await _getLatlng();

      Map<String, dynamic> data = {
        "matricule": tagsController.faceResult.value,
        "station_id": tagsController.activeStation.value?['id'],
        "coordonnees": latlng,
        "key": key.toLowerCase().replaceAll(" ", "-"),
      };

      var response = await Api.request(
        url: "agent.punch",
        method: "post",
        body: data,
        files: {'photo': File(tagsController.face.value!.path)},
      );

      return (response != null && response is Map && !response.containsKey("errors")) ? "success" : _extractErrorMessage(response);
    } catch (e) {
      return "Erreur pointage";
    }
  }
}

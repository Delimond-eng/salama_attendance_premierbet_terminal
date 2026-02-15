import 'dart:async';
import 'dart:io';

import '/global/controllers.dart';
import '/kernel/services/api.dart';

class HttpManager {
  /// Extrait un message d'erreur lisible depuis la réponse Laravel
  String _extractErrorMessage(dynamic response) {
    if (response == null) return "Le serveur n'a renvoyé aucune réponse.";

    if (response is Map) {
      if (response.containsKey("errors")) {
        var err = response["errors"];
        if (err is List && err.isNotEmpty) return err[0].toString();
        if (err is Map && err.isNotEmpty) {
          var firstVal = err.values.first;
          return firstVal is List
              ? firstVal[0].toString()
              : firstVal.toString();
        }
        return err.toString();
      }
      if (response.containsKey("message"))
        return response["message"].toString();
    }
    return "Une erreur inconnue est survenue.";
  }

  /// Enrôle la photo d'un agent
  Future<dynamic> enrollAgent(String matricule) async {
    try {
      var data = {"matricule": matricule};
      var response = await Api.request(
        url: "agent.enroll",
        method: "post",
        files: {"photo": File(tagsController.face.value!.path)},
        body: data,
      );

      if (response != null && response is Map) {
        if (response["status"] == "success") return "success";
        return _extractErrorMessage(response);
      }
      return _extractErrorMessage(response);
    } catch (e) {
      return "Échec de traitement de la requête : $e";
    }
  }

  /// Identifie la station
  Future<dynamic> identifyStation() async {
    try {
      var stationId = tagsController.activeStation.value?['id'];
      var data = {"station_id": stationId ?? 1};
      var response = await Api.request(
        url: "station.scan",
        method: "post",
        body: data,
      );
      if (response != null && response is Map) {
        if (response.containsKey("errors"))
          return _extractErrorMessage(response);
        return "success";
      }
      return _extractErrorMessage(response);
    } catch (e) {
      return "Échec de traitement de la requête !";
    }
  }

  /// Signale la présence (Check-in / Check-out)
  Future<dynamic> checkPresence({required String key}) async {
    try {
      String formattedKey = key.toLowerCase().replaceAll(" ", "-");
      Map<String, dynamic> data = {
        "matricule": tagsController.faceResult.value,
        "station_id": tagsController.activeStation.value?['id'],
        "coordonnees": "",
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
          return _extractErrorMessage(response);
        }
        return "success"; // On force le retour success
      }
      return _extractErrorMessage(response);
    } catch (e) {
      return "Échec de traitement de la requête biométrique.";
    }
  }
}

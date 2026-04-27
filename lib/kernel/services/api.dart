import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Api {
  //static String baseUrl = 'http://salama.uco.rod.mybluehost.me/api';
  //static String baseUrl = 'https://mamba.salama-drc.com/api';
  static String baseUrl = 'https://rdtech.salama-drc.com/api';

  static Future<dynamic> request({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, File>? files,
  }) async {
    final fullUrl = Uri.parse('$baseUrl/$url');
    const apiKey = "16jA/0l6TBmFoPk64MnrmLzVp2MRL2Do0yD5N6K4e54=";

    // Tentative de contournement du JavaScript Challenge en simulant le cookie requis
    headers = {
      'Content-Type': 'application/json',
      'X-API-KEY': apiKey,
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 11; SM-G960F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Mobile Safari/537.36',
      'Cookie': 'humans_21909=1', // Injection du cookie de validation BitNinja
      ...?headers,
    };

    http.Response response;
    try {
      if (files != null && files.isNotEmpty) {
        var request = http.MultipartRequest(method.toUpperCase(), fullUrl);
        request.headers.addAll(headers);

        if (body != null) {
          for (var entry in body.entries) {
            if (entry.value is Map) {
              (entry.value as Map).forEach((subKey, subValue) {
                if (subValue != null) {
                  request.fields['${entry.key}[$subKey]'] = subValue.toString();
                }
              });
            } else {
              if (entry.value != null) {
                request.fields[entry.key] = entry.value.toString();
              }
            }
          }
        }
        for (var entry in files.entries) {
          var fileBytes = await entry.value.readAsBytes();
          var multipartFile = http.MultipartFile.fromBytes(
            entry.key,
            fileBytes,
            filename: entry.value.path.split("/").last,
          );
          request.files.add(multipartFile);
        }
        var streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        switch (method.toLowerCase()) {
          case 'post':
            response = await http.post(
              fullUrl,
              headers: headers,
              body: jsonEncode(body ?? {}),
            );
            break;
          case 'get':
            response = await http.get(fullUrl, headers: headers);
            break;
          case 'put':
            response = await http.put(
              fullUrl,
              headers: headers,
              body: jsonEncode(body ?? {}),
            );
            break;
          default:
            throw Exception("Méthode HTTP non prise en charge : $method");
        }
      }

      if (kDebugMode) {
        print("API Response ($url): ${response.body}");
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        // En cas d'erreur 409 persistante, on affiche un log clair
        if (response.body.contains("humans_21909")) {
          print(
            "❌ ALERTE: Le pare-feu BitNinja bloque toujours l'API. Contactez l'hébergeur.",
          );
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception API ($url): $e');
      }
      return null;
    }
  }
}

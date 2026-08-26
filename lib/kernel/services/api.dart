import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Api {
  static String baseUrl = 'https://md.salama-drc.com/api';
  //static String baseUrl = 'https://mamba.salama-drc.com/api';
  //static String baseUrl = 'https://chanimetal.salama-drc.com/api';

  static Future<dynamic> request({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, File>? files,
  }) async {
    Uri fullUrl = Uri.parse('$baseUrl/$url');

    // Handle GET parameters
    if (method.toLowerCase() == 'get' && body != null) {
      fullUrl = fullUrl.replace(
        queryParameters: body.map(
          (key, value) => MapEntry(key, value?.toString() ?? ""),
        ),
      );
    }

    const apiKey = "16jA/0l6TBmFoPk64MnrmLzVp2MRL2Do0yD5N6K4e54=";

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

      // Return body regardless of status code to let HttpManager handle errors/messages
      try {
        return jsonDecode(response.body);
      } catch (_) {
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

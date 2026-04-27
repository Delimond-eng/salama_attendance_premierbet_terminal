import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '/kernel/models/face.dart';
import '/kernel/services/database_helper.dart';

List<List<List<List<double>>>> processImage(Map<String, dynamic> args) {
  try {
    final Uint8List bytes = args['bytes'];
    final int left = args['left'];
    final int top = args['top'];
    final int width = args['width'];
    final int height = args['height'];

    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) return [];

    final int safeLeft = (left - (width * 0.1))
        .clamp(0, originalImage.width - 1)
        .toInt();
    final int safeTop = (top - (height * 0.1))
        .clamp(0, originalImage.height - 1)
        .toInt();
    final int safeWidth = (width * 1.2)
        .clamp(1, originalImage.width - safeLeft)
        .toInt();
    final int safeHeight = (height * 1.2)
        .clamp(1, originalImage.height - safeTop)
        .toInt();

    final cropped = img.copyCrop(
      originalImage,
      safeLeft,
      safeTop,
      safeWidth,
      safeHeight,
    );
    final resized = img.copyResizeCropSquare(cropped, 112);

    return List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(112, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            (img.getRed(pixel) - 127.5) / 128.0,
            (img.getGreen(pixel) - 127.5) / 128.0,
            (img.getBlue(pixel) - 127.5) / 128.0,
          ];
        }),
      ),
    );
  } catch (e) {
    debugPrint("Isolate process error: $e");
    return [];
  }
}

class FaceRecognitionController extends GetxController {
  static FaceRecognitionController instance = Get.find();

  Interpreter? _interpreter;
  final isModelLoaded = false.obs;
  final List<FacePicture> _storedTemplates = [];

  @override
  void onInit() {
    super.onInit();
    initializeModel();
  }

  Future<void> initializeModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/facenet.tflite',
      );
      await reloadTemplates();
      isModelLoaded.value = true;
      debugPrint('FaceNet model loaded successfully');
    } catch (e) {
      isModelLoaded.value = false;
      debugPrint('Model init error: $e');
      // Visible en release pour le debug
      EasyLoading.showError("Erreur chargement IA: $e");
    }
  }

  Future<void> reloadTemplates() async {
    try {
      await DatabaseHelper().init();
      final faces = await DatabaseHelper().getAllFaces();
      _storedTemplates.clear();
      _storedTemplates.addAll(faces);
    } catch (e) {
      debugPrint('Reload templates error: $e');
    }
  }

  Future<void> addKnownFaceFromImage(
    String matricule,
    String? name,
    XFile image,
  ) async {
    final embedding = await getEmbedding(image);
    if (embedding == null) return;

    final face = FacePicture(
      matricule: matricule,
      name: name,
      embedding: embedding,
    );
    await DatabaseHelper().insertFace(face);
    _storedTemplates.add(face);
  }

  Future<List<double>?> getEmbedding(XFile imageFile) async {
    try {
      if (_interpreter == null) {
        EasyLoading.showError("Moteur IA non prêt");
        return null;
      }

      final inputImage = InputImage.fromFilePath(imageFile.path);
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      final faces = await detector.processImage(inputImage);
      await detector.close();

      if (faces.isEmpty) {
        debugPrint("No face detected in capture");
        return null;
      }

      final faceBox = faces.first.boundingBox;
      final bytes = await imageFile.readAsBytes();

      // compute() peut être instable en Release si mal configuré
      final input = await compute(processImage, {
        'bytes': bytes,
        'left': faceBox.left.toInt(),
        'top': faceBox.top.toInt(),
        'width': faceBox.width.toInt(),
        'height': faceBox.height.toInt(),
      });

      if (input.isEmpty) return null;

      final output = List.filled(128, 0.0).reshape([1, 128]);
      _interpreter!.run(input, output);

      final List<double> result = List<double>.from(output[0]);
      double sum = 0;
      for (var v in result) sum += v * v;
      double norm = sqrt(sum);
      return result.map((e) => e / (norm > 0 ? norm : 1.0)).toList();
    } catch (e) {
      EasyLoading.showError("Erreur biométrique: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> recognizeFaceFromImage(XFile? image) async {
    if (image == null) return null;
    final embedding = await getEmbedding(image);
    if (embedding == null) return null;

    FacePicture? closestTemplate;
    double minDistance = double.infinity;

    for (final template in _storedTemplates) {
      final distance = euclideanDistance(template.embedding, embedding);
      if (distance < minDistance) {
        minDistance = distance;
        closestTemplate = template;
      }
    }
    if (closestTemplate != null && minDistance < 0.60) {
      return {
        'matricule': closestTemplate.matricule,
        'name': closestTemplate.name ?? 'Inconnu',
      };
    }
    return null;
  }

  double euclideanDistance(List<double> e1, List<double> e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      final diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }
}

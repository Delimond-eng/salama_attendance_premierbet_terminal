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
  final Uint8List bytes = args['bytes'];
  final int left = args['left'];
  final int top = args['top'];
  final int width = args['width'];
  final int height = args['height'];

  final originalImage = img.decodeImage(bytes);
  if (originalImage == null) return [];

  final int safeLeft = left.clamp(0, originalImage.width - 1).toInt();
  final int safeTop = top.clamp(0, originalImage.height - 1).toInt();
  final int safeWidth = width.clamp(1, originalImage.width - safeLeft).toInt();
  final int safeHeight = height.clamp(1, originalImage.height - safeTop).toInt();

  final cropped = img.copyCrop(originalImage, safeLeft, safeTop, safeWidth, safeHeight);
  final resized = img.copyResizeCropSquare(cropped, 112);

  return List.generate(
    1,
    (_) => List.generate(
      112,
      (y) => List.generate(
        112,
        (x) {
          final pixel = resized.getPixel(x, y);
          return [
            (img.getRed(pixel) - 127.5) / 127.5,
            (img.getGreen(pixel) - 127.5) / 127.5,
            (img.getBlue(pixel) - 127.5) / 127.5,
          ];
        },
      ),
    ),
  );
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
      _interpreter = await Interpreter.fromAsset('assets/models/facenet.tflite');
      await reloadTemplates();
      isModelLoaded.value = true;
    } catch (e) {
      debugPrint('Model init error: $e');
    }
  }

  Future<void> reloadTemplates() async {
    await DatabaseHelper().init();
    final faces = await DatabaseHelper().getAllFaces();
    _storedTemplates.clear();
    _storedTemplates.addAll(faces);
  }

  Future<void> addKnownFaceFromImage(String matricule, XFile image) async {
    final embedding = await getEmbedding(image);
    if (embedding == null) return;

    final face = FacePicture(matricule: matricule, embedding: embedding);
    await DatabaseHelper().insertFace(face);
    _storedTemplates.add(face);
  }

  Future<List<double>?> getEmbedding(XFile imageFile) async {
    if (_interpreter == null) return null;

    final inputImage = InputImage.fromFilePath(imageFile.path);
    final detector = FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate));
    final faces = await detector.processImage(inputImage);
    await detector.close();

    if (faces.isEmpty) return null;

    final faceBox = faces.first.boundingBox;
    
    // FILTRAGE DE QUALITÉ : On refuse les visages trop petits/loins pour éviter les erreurs
    if (faceBox.width < 80 || faceBox.height < 80) return null;

    final bytes = await imageFile.readAsBytes();

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
    return result.map((e) => e / norm).toList();
  }

  Future<String?> recognizeFaceFromImage(XFile? image) async {
    if (image == null) return null;
    final embedding = await getEmbedding(image);
    if (embedding == null) return 'Inconnu';

    String? closestMatricule;
    double minDistance = double.infinity;

    for (final template in _storedTemplates) {
      final distance = euclideanDistance(template.embedding, embedding);
      if (distance < minDistance) {
        minDistance = distance;
        closestMatricule = template.matricule;
      }
    }

    // RÉGLAGE DE PRÉCISION : Seuil abaissé à 0.60 (plus strict)
    // Entre 0.0 et 0.60 : Match solide.
    // Au dessus de 0.60 : Trop incertain, on rejette.
    if (closestMatricule != null && minDistance < 0.60) {
      debugPrint("MATCH SUCCESS: $closestMatricule (Distance: $minDistance)");
      return closestMatricule;
    }
    
    debugPrint("MATCH FAILED: Best was $closestMatricule with distance $minDistance");
    return 'Inconnu';
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

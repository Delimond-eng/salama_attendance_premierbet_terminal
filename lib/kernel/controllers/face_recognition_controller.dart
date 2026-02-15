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

  // Keep crop inside bounds to avoid intermittent extraction failures.
  final int safeLeft = left.clamp(0, originalImage.width - 1).toInt();
  final int safeTop = top.clamp(0, originalImage.height - 1).toInt();
  final int safeRight =
      (safeLeft + width).clamp(safeLeft + 1, originalImage.width).toInt();
  final int safeBottom =
      (safeTop + height).clamp(safeTop + 1, originalImage.height).toInt();
  final int safeWidth = safeRight - safeLeft;
  final int safeHeight = safeBottom - safeTop;

  if (safeWidth <= 0 || safeHeight <= 0) return [];

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
      (y) => List.generate(
        112,
        (x) {
          final pixel = resized.getPixel(x, y);
          return [
            (img.getRed(pixel) - 128) / 128.0,
            (img.getGreen(pixel) - 128) / 128.0,
            (img.getBlue(pixel) - 128) / 128.0,
          ];
        },
      ),
    ),
  );
}

class FaceRecognitionController extends GetxController {
  static FaceRecognitionController instance = Get.find();

  Interpreter? _interpreter;
  Future<void>? _modelInitializationFuture;

  final isModelLoaded = false.obs;
  final isModelInitializing = false.obs;
  final modelLoadingError = RxnString();

  final isRecognitionLoading = false.obs;
  final faces = Rx<XFile?>(null);
  final faceResult = ''.obs;
  final recognitionKey = ''.obs;

  final Map<String, List<double>> _knownFaces = {};

  @override
  void onInit() {
    super.onInit();
    initializeModel();
  }

  Future<void> initializeModel() async {
    if (isModelLoaded.value) return;

    final pendingInit = _modelInitializationFuture;
    if (pendingInit != null) {
      await pendingInit;
      return;
    }

    isModelInitializing.value = true;

    late final Future<void> initFuture;
    initFuture = () async {
      try {
        _interpreter =
            await Interpreter.fromAsset('assets/models/facenet.tflite');

        await DatabaseHelper().init();
        final storedFaces = await DatabaseHelper().getAllFaces();

        _knownFaces.clear();
        for (final face in storedFaces) {
          _knownFaces[face.matricule] = face.embedding;
        }

        isModelLoaded.value = true;
        modelLoadingError.value = null;
      } catch (e) {
        modelLoadingError.value = 'Erreur de chargement du modele: $e';
      } finally {
        isModelInitializing.value = false;
        if (identical(_modelInitializationFuture, initFuture)) {
          _modelInitializationFuture = null;
        }
      }
    }();

    _modelInitializationFuture = initFuture;
    await initFuture;
  }

  Future<bool> _ensureModelReady() async {
    if (!isModelLoaded.value || _interpreter == null) {
      await initializeModel();
    }
    return _interpreter != null && isModelLoaded.value;
  }

  Future<List<Face>> _detectFaces(
    InputImage inputImage,
    FaceDetectorMode mode,
  ) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: mode,
        minFaceSize: 0.08,
      ),
    );

    try {
      return await detector.processImage(inputImage);
    } finally {
      await detector.close();
    }
  }

  Face _pickPrimaryFace(List<Face> detectedFaces) {
    return detectedFaces.reduce((faceA, faceB) {
      final areaA = faceA.boundingBox.width * faceA.boundingBox.height;
      final areaB = faceB.boundingBox.width * faceB.boundingBox.height;
      return areaA >= areaB ? faceA : faceB;
    });
  }

  // Add known face from image
  Future<void> addKnownFaceFromImage(String matricule, XFile image) async {
    final embedding = await getEmbedding(image);
    if (embedding == null) {
      EasyLoading.showInfo(
        "Visage non detecte dans l'image ${image.name}. Enrolement interrompu.",
      );
      throw Exception(
        "Visage non detecte dans l'image ${image.name}. Enrolement interrompu.",
      );
    }

    _knownFaces[matricule] = embedding;

    await DatabaseHelper().insertFace(
      FacePicture(matricule: matricule, embedding: embedding),
    );
  }

  Future<void> recognize(XFile? image) async {
    isRecognitionLoading.value = true;
    try {
      if (image == null) {
        faceResult.value = 'Annule';
        return;
      }

      faces.value = image;
      final result = await recognizeFaceFromImage(image);
      faceResult.value = result;
    } catch (e) {
      faceResult.value = 'Erreur : $e';
    } finally {
      isRecognitionLoading.value = false;
    }
  }

  // Embedding normalization
  List<double>? _normalize(List<double> input) {
    final norm = sqrt(input.fold(0.0, (sum, val) => sum + val * val));
    if (norm == 0) return null;
    return input.map((e) => e / norm).toList();
  }

  // Extract embedding from image
  Future<List<double>?> getEmbedding(XFile imageFile) async {
    try {
      final ready = await _ensureModelReady();
      if (!ready) {
        if (kDebugMode) {
          print('Modele facenet indisponible au moment de l\'inference');
        }
        return null;
      }

      final inputImage = InputImage.fromFilePath(imageFile.path);

      var detectedFaces = await _detectFaces(
        inputImage,
        FaceDetectorMode.accurate,
      );
      if (detectedFaces.isEmpty) {
        detectedFaces = await _detectFaces(inputImage, FaceDetectorMode.fast);
      }

      if (detectedFaces.isEmpty) {
        if (kDebugMode) {
          print('Aucun visage detecte dans ${imageFile.path}');
        }
        return null;
      }

      final faceBox = _pickPrimaryFace(detectedFaces).boundingBox;
      final bytes = await imageFile.readAsBytes();

      final paddedLeft = (faceBox.left - faceBox.width * 0.12).floor();
      final paddedTop = (faceBox.top - faceBox.height * 0.12).floor();
      final paddedWidth = max(1, (faceBox.width * 1.24).round());
      final paddedHeight = max(1, (faceBox.height * 1.24).round());

      final input = await compute(processImage, {
        'bytes': bytes,
        'left': paddedLeft,
        'top': paddedTop,
        'width': paddedWidth,
        'height': paddedHeight,
      });

      if (input.isEmpty) {
        if (kDebugMode) {
          print('Crop visage invalide pour ${imageFile.path}');
        }
        return null;
      }

      final interpreter = _interpreter;
      if (interpreter == null) {
        if (kDebugMode) {
          print('Interpreter null pendant l\'inference');
        }
        return null;
      }

      final output = List.filled(128, 0.0).reshape([1, 128]);
      interpreter.run(input, output);

      return _normalize(List<double>.from(output[0]));
    } catch (e) {
      if (kDebugMode) print('Erreur dans getEmbedding : $e');
      return null;
    }
  }

  // Face recognition from image
  Future<dynamic> recognizeFaceFromImage(XFile? image) async {
    try {
      if (image == null) {
        EasyLoading.showInfo("Operation annulee par l'utilisateur");
        return null;
      }

      final embedding = await getEmbedding(image);
      if (embedding == null) {
        EasyLoading.showInfo("Impossible d'obtenir l'empreinte du visage");
        return null;
      }

      String? closestName;
      double minDistance = double.infinity;

      for (final entry in _knownFaces.entries) {
        final distance = euclideanDistance(entry.value, embedding);
        if (distance < minDistance) {
          minDistance = distance;
          closestName = entry.key;
        }
      }

      if (closestName == null) return 'Inconnu';
      return (minDistance < 0.7) ? closestName : 'Inconnu';
    } catch (_) {
      return null;
    }
  }

  // Euclidean distance
  double euclideanDistance(List<double> e1, List<double> e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      final diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }
}


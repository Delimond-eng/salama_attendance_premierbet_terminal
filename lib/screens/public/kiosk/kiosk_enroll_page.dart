import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '/global/controllers.dart';
import '/kernel/services/http_manager.dart';
import '/kernel/controllers/face_recognition_controller.dart';
import 'kiosk_components.dart';

class KioskEnrollPage extends StatefulWidget {
  const KioskEnrollPage({
    super.key,
    required this.onSuccess,
    required this.onCancel,
  });

  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  @override
  State<KioskEnrollPage> createState() => _KioskEnrollPageState();
}

class _KioskEnrollPageState extends State<KioskEnrollPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final List<XFile> _capturedImages = [];
  bool _isDetecting = false;
  bool _facePresent = false;
  bool _allPhotosTaken = false;
  bool _isCapturing = false;
  final TextEditingController _matriculeController = TextEditingController();
  
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      ),
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});

      _controller!.startImageStream((image) {
        if (_isDetecting || _allPhotosTaken) return;
        _isDetecting = true;
        _checkFacePresence(image);
      });
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _checkFacePresence(CameraImage image) async {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isDetecting = false;
      return;
    }

    final faces = await _faceDetector.processImage(inputImage);
    if (mounted) {
      setState(() {
        _facePresent = faces.isNotEmpty;
      });
    }
    _isDetecting = false;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final bytes = Uint8List.fromList(
        image.planes.fold<List<int>>([], (buffer, plane) => buffer..addAll(plane.bytes)),
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _takeManualPhoto() async {
    if (_isCapturing || _capturedImages.length >= 3) return;

    setState(() => _isCapturing = true);
    try {
      final photo = await _controller!.takePicture();
      setState(() {
        _capturedImages.add(photo);
        if (_capturedImages.length == 3) {
          _allPhotosTaken = true;
          _controller!.stopImageStream();
        }
      });
    } catch (e) {
      EasyLoading.showError("Erreur lors de la capture");
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _submitEnroll() async {
    final matricule = _matriculeController.text.trim();
    if (matricule.isEmpty) {
      EasyLoading.showInfo("Matricule requis");
      return;
    }
    
    EasyLoading.show(status: 'Synchronisation avec le serveur...');
    
    try {
      tagsController.face.value = _capturedImages.first;
      final response = await HttpManager().enrollAgent(matricule);
      
      if (response != null && response is Map && response["status"] == "success") {
        final agentData = response["result"] as Map?;
        final String? agentName = agentData != null ? agentData["fullname"] : null;

        for (var imgFile in _capturedImages) {
          await faceRecognitionController.addKnownFaceFromImage(
            matricule,
            agentName,
            imgFile,
          );
        }

        EasyLoading.showSuccess("Agent ${agentName ?? matricule} enrôlé");
        widget.onSuccess();
        Get.back();
      } else {
        EasyLoading.showError(response != null ? response["message"].toString() : "Erreur serveur");
      }
    } catch (e) {
      EasyLoading.showError("Échec : $e");
    } finally {
      EasyLoading.dismiss();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    _matriculeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, 
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: KioskColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const Spacer(),
                    const KioskBadge(label: "ADMIN : ENRÔLEMENT"),
                  ],
                ),
                SizedBox(height: 20 * scale),
                Text(
                  _allPhotosTaken ? "Prêt à valider" : (_facePresent ? "Visage détecté : Prêt" : "Cadrez le visage"),
                  style: kioskTitle(context).copyWith(fontSize: 22 * scale, color: _facePresent ? KioskColors.success : KioskColors.textHigh),
                ),
                SizedBox(height: 24 * scale),
                
                Center(
                  child: Container(
                    width: 280 * scale,
                    height: 280 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _facePresent ? KioskColors.success : KioskColors.primary, width: 4),
                    ),
                    child: ClipOval(
                      child: (_controller != null && _controller!.value.isInitialized)
                          ? FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.previewSize?.height,
                                height: _controller!.value.previewSize?.width,
                                child: CameraPreview(_controller!),
                              ),
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
                
                SizedBox(height: 20 * scale),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final hasImage = index < _capturedImages.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 64 * scale,
                      height: 64 * scale,
                      decoration: BoxDecoration(
                        color: KioskColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasImage ? KioskColors.success : KioskColors.outline,
                          width: 2
                        ),
                      ),
                      child: hasImage 
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(_capturedImages[index].path), fit: BoxFit.cover),
                          )
                        : Icon(Icons.face_rounded, color: KioskColors.textLow.withOpacity(0.3)),
                    );
                  }),
                ),
    
                SizedBox(height: 32 * scale),
    
                if (!_allPhotosTaken)
                  ElevatedButton.icon(
                    onPressed: (_isCapturing || !_facePresent) ? null : _takeManualPhoto,
                    icon: _isCapturing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.camera_alt_rounded),
                    label: Text("CAPTURER PHOTO ${_capturedImages.length + 1}/3"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KioskColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: KioskColors.outline.withOpacity(0.5),
                      minimumSize: Size(220 * scale, 60 * scale),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  )
                else
                  KioskCard(
                    padding: EdgeInsets.all(16 * scale),
                    child: Column(
                      children: [
                        TextField(
                          controller: _matriculeController,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Ubuntu'),
                          decoration: const InputDecoration(
                            labelText: "Matricule de l'agent",
                            hintText: "Ex: AGT-0012",
                            prefixIcon: Icon(Icons.badge_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 20 * scale),
                        ElevatedButton(
                          onPressed: _submitEnroll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KioskColors.success,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("VALIDER L'ENRÔLEMENT", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Ubuntu')),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

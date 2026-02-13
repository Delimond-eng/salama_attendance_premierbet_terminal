import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '/global/controllers.dart';
import '/kernel/services/http_manager.dart';
import 'kiosk_components.dart';

class KioskFaceScanPage extends StatefulWidget {
  const KioskFaceScanPage({super.key, required this.onSuccess, required this.onCancel});
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  @override
  State<KioskFaceScanPage> createState() => _KioskFaceScanPageState();
}

class _KioskFaceScanPageState extends State<KioskFaceScanPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;
  String? _detectedMatricule;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () => _initCamera());
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    await _controller?.dispose();
    _controller = CameraController(
      cameras[tagsController.cameraIndex.value],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      _initializeControllerFuture = _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Erreur Camera: $e");
    }
  }

  void _switchCamera() async {
    tagsController.cameraIndex.value = (tagsController.cameraIndex.value + 1) % 2;
    await _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndAnalyze() async {
    try {
      final image = await _controller?.takePicture();
      if (image == null) return;

      setState(() {
        _capturedImage = image;
        _isAnalyzing = true;
        _detectedMatricule = null;
      });

      final matricule = await faceRecognitionController.recognizeFaceFromImage(image);
      
      if (mounted) {
        setState(() {
          _detectedMatricule = matricule;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur capture/analyse: $e");
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return Scaffold(
      backgroundColor: KioskColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Row(children: [
              IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: KioskColors.textHigh)),
              const SizedBox(width: 48),
            ]),
            SizedBox(height: 32 * scale),
            Obx(() => Text("${tagsController.attendanceType.value.toUpperCase()} - VÉRIFICATION",
                style: kioskTitle(context))),
            const Spacer(),
            Column(
              children: [
                Container(
                  width: 340 * scale,
                  height: 340 * scale,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, border: Border.all(color: KioskColors.primary, width: 4)),
                  child: ClipOval(
                      child: _capturedImage != null
                          ? Image.file(File(_capturedImage!.path), fit: BoxFit.cover)
                          : FutureBuilder<void>(
                              future: _initializeControllerFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done && _controller != null) {
                                  return FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                          width: _controller!.value.previewSize?.height,
                                          height: _controller!.value.previewSize?.width,
                                          child: CameraPreview(_controller!)));
                                }
                                return const Center(child: CircularProgressIndicator());
                              },
                            )),
                ),
                if (_capturedImage != null) ...[
                  SizedBox(height: 20 * scale),
                  if (_isAnalyzing)
                    const CircularProgressIndicator()
                  else if (_detectedMatricule != null && _detectedMatricule != "Inconnu")
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: KioskColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: KioskColors.success, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_rounded, color: KioskColors.success, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _detectedMatricule!,
                            style: const TextStyle(
                              color: KioskColors.success,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Poppins',
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: KioskColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: KioskColors.danger, width: 2),
                      ),
                      child: const Text(
                        "VISAGE INCONNU",
                        style: TextStyle(
                          color: KioskColors.danger,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Poppins',
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ],
            ),
            const Spacer(),
            if (_capturedImage == null)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                CaptureAction(
                    icon: Icons.flip_camera_ios_rounded, label: "CAMÉRA", color: Colors.blue.shade400, onTap: _switchCamera),
                SizedBox(width: 24 * scale),
                CaptureAction(
                    icon: Icons.camera_alt_rounded,
                    label: "CAPTURER",
                    isLarge: true,
                    color: KioskColors.primary,
                    onTap: _captureAndAnalyze),
                SizedBox(width: 24 * scale),
                CaptureAction(
                    icon: Icons.close_rounded, label: "ANNULER", color: Colors.grey.shade400, onTap: widget.onCancel),
              ])
            else
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                CaptureAction(
                    icon: Icons.refresh_rounded,
                    label: "REPRENDRE",
                    color: KioskColors.textMid,
                    onTap: () => setState(() {
                      _capturedImage = null;
                      _detectedMatricule = null;
                    })),
                if (_detectedMatricule != null && _detectedMatricule != "Inconnu") ...[
                  SizedBox(width: 40 * scale),
                  CaptureAction(
                      icon: Icons.check_rounded,
                      label: "VALIDER",
                      isLarge: true,
                      color: KioskColors.success,
                      onTap: () async {
                        EasyLoading.show(status: 'Envoi...');
                        tagsController.faceResult.value = _detectedMatricule!;
                        tagsController.face.value = _capturedImage;
                        
                        final res = await HttpManager().checkPresence(key: tagsController.attendanceType.value);
                        
                        EasyLoading.dismiss();
                        
                        if (res == "success") {
                          Get.back(); // Ferme la caméra
                          widget.onSuccess();
                        } else {
                          // Affiche l'erreur réelle (ex: "Pointage déjà effectué")
                          EasyLoading.showInfo(res.toString(), duration: const Duration(seconds: 4));
                          setState(() {
                            _capturedImage = null;
                            _detectedMatricule = null;
                          });
                        }
                      }),
                ],
              ]),
            SizedBox(height: 48 * scale),
          ]),
        ),
      ),
    );
  }
}

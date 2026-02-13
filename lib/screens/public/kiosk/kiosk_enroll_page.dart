import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '/global/controllers.dart';
import '/kernel/services/http_manager.dart';
import 'kiosk_components.dart';

class KioskEnrollPage extends StatefulWidget {
  const KioskEnrollPage({super.key, required this.onSuccess, required this.onCancel});
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  @override
  State<KioskEnrollPage> createState() => _KioskEnrollPageState();
}

class _KioskEnrollPageState extends State<KioskEnrollPage> {
  final TextEditingController _matriculeController = TextEditingController();
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;

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
    _initializeControllerFuture = _controller!.initialize();
    if (mounted) setState(() {});
  }

  void _switchCamera() async {
    tagsController.cameraIndex.value = (tagsController.cameraIndex.value + 1) % 2;
    await _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _matriculeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return Scaffold(
      backgroundColor: KioskColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Row(children: [
              IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: KioskColors.textHigh)),
              const SizedBox(width: 48),
            ]),
            SizedBox(height: 32 * scale),
            Text("NOUVEL ENRÔLEMENT", textAlign: .center, style: kioskTitle(context).copyWith(fontSize: 20.0)),
            SizedBox(height: 24 * scale),
            Container(
              width: 280 * scale,
              height: 280 * scale,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: KioskColors.primary, width: 4)),
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
                                  child: CameraPreview(_controller!),
                                ),
                              );
                            }
                            return const Center(child: CircularProgressIndicator());
                          },
                        )),
            ),
            SizedBox(height: 32 * scale),
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
                    onTap: () async {
                      final image = await _controller?.takePicture();
                      setState(() => _capturedImage = image);
                    }),
              ])
            else ...[
              KioskCard(
                  child: Column(children: [
                TextField(
                    controller: _matriculeController,
                    decoration: InputDecoration(
                        labelText: "MATRICULE",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        prefixIcon: const Icon(Icons.badge))),
                SizedBox(height: 24 * scale),
                KioskPrimaryButton(
                    label: "VALIDER L'ENRÔLEMENT",
                    icon: Icons.how_to_reg_rounded,
                    onPressed: () async {
                      if (_matriculeController.text.isEmpty) {
                        EasyLoading.showInfo("Matricule requis");
                        return;
                      }
                      EasyLoading.show(status: 'Enrôlement...');
                      tagsController.face.value = _capturedImage;
                      await faceRecognitionController.addKnownFaceFromImage(_matriculeController.text, _capturedImage!);
                      final res = await HttpManager().enrollAgent(_matriculeController.text);
                      EasyLoading.dismiss();
                      if (res == "success") {
                        Get.back();
                        widget.onSuccess();
                      } else {
                        EasyLoading.showError(res.toString());
                      }
                    }),
              ])),
              SizedBox(height: 16 * scale),
              KioskGhostButton(
                  label: "REPRENDRE LA PHOTO",
                  icon: Icons.refresh_rounded,
                  onPressed: () => setState(() => _capturedImage = null)),
            ],
          ]),
        ),
      ),
    );
  }
}

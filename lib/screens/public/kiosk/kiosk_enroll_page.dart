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

class _KioskEnrollPageState extends State<KioskEnrollPage>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final List<XFile> _capturedImages = [];
  bool _isDetecting = false;
  bool _facePresent = false;
  bool _allPhotosTaken = false;
  bool _isCapturing = false;
  final TextEditingController _matriculeController = TextEditingController();

  // Anneau de recherche animé autour du cercle caméra tant qu'aucun
  // visage n'est détecté. Purement visuel, ne touche à aucune logique
  // de détection ou de capture.
  late final AnimationController _pulseController;

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
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
    _pulseController.dispose();
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
                    _GhostIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: widget.onCancel,
                    ),
                    const Spacer(),
                    const KioskBadge(label: "ADMIN : ENRÔLEMENT"),
                  ],
                ),
                SizedBox(height: 20 * scale),
                Text(
                  _allPhotosTaken
                      ? "Prêt à valider"
                      : (_facePresent ? "Visage détecté : Prêt" : "Cadrez le visage"),
                  style: kioskTitle(context).copyWith(
                    fontSize: 22 * scale,
                    color: _facePresent ? KioskColors.success : KioskColors.textHigh,
                  ),
                ),
                SizedBox(height: 6 * scale),
                Text(
                  _allPhotosTaken
                      ? "Renseignez le matricule pour finaliser"
                      : "Photo ${_capturedImages.length + 1} sur 3",
                  style: TextStyle(
                    fontSize: 13 * scale,
                    color: KioskColors.textLow,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Ubuntu',
                  ),
                ),
                SizedBox(height: 24 * scale),

                _buildCameraCircle(scale),

                SizedBox(height: 20 * scale),

                _buildPhotoSlots(scale),

                SizedBox(height: 32 * scale),

                if (!_allPhotosTaken)
                  _buildCaptureButton(scale)
                else
                  _buildValidationCard(scale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraCircle(double scale) {
    final bool searching = !_facePresent && !_allPhotosTaken;

    return Center(
      child: SizedBox(
        width: 320 * scale,
        height: 320 * scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (searching)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final t = _pulseController.value;
                  return Container(
                    width: (282 + t * 24) * scale,
                    height: (282 + t * 24) * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: KioskColors.primary.withOpacity(0.35 - t * 0.22),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            Container(
              width: 280 * scale,
              height: 280 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _facePresent ? KioskColors.success : KioskColors.primary,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_facePresent ? KioskColors.success : KioskColors.primary)
                        .withOpacity(0.18),
                    blurRadius: 24 * scale,
                  ),
                ],
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
            if (_facePresent)
              Positioned(
                right: 8 * scale,
                bottom: 8 * scale,
                child: Container(
                  width: 36 * scale,
                  height: 36 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: KioskColors.success,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(Icons.check_rounded, color: Colors.white, size: 20 * scale),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSlots(double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final hasImage = index < _capturedImages.length;
        final isNext = !hasImage && index == _capturedImages.length && !_allPhotosTaken;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 8 * scale),
          width: 64 * scale,
          height: 64 * scale,
          decoration: BoxDecoration(
            color: KioskColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasImage
                  ? KioskColors.success
                  : (isNext ? KioskColors.primary : KioskColors.outline),
              width: isNext ? 2.5 : 2,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: hasImage
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(_capturedImages[index].path), fit: BoxFit.cover),
                )
                    : Center(
                  child: Icon(
                    Icons.face_rounded,
                    color: isNext
                        ? KioskColors.primary.withOpacity(0.55)
                        : KioskColors.textLow.withOpacity(0.3),
                  ),
                ),
              ),
              if (hasImage)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 18 * scale,
                    height: 18 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: KioskColors.success,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 11 * scale),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCaptureButton(double scale) {
    return ElevatedButton.icon(
      onPressed: (_isCapturing || !_facePresent) ? null : _takeManualPhoto,
      icon: _isCapturing
          ? SizedBox(
        width: 20 * scale,
        height: 20 * scale,
        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      )
          : Icon(Icons.camera_alt_rounded, size: 20 * scale),
      label: Text(
        "CAPTURER PHOTO ${_capturedImages.length + 1}/3",
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontFamily: 'Ubuntu',
          letterSpacing: 0.4,
        ),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: KioskColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: KioskColors.outline.withOpacity(0.4),
        minimumSize: Size(240 * scale, 58 * scale),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildValidationCard(double scale) {
    return KioskCard(
      padding: EdgeInsets.all(18 * scale),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: KioskColors.success, size: 18 * scale),
              SizedBox(width: 8 * scale),
              Text(
                "3 PHOTOS CAPTURÉES",
                style: TextStyle(
                  fontSize: 11.5 * scale,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: KioskColors.textLow,
                  fontFamily: 'Ubuntu',
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          TextField(
            controller: _matriculeController,
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Ubuntu'),
            decoration: InputDecoration(
              labelText: "Matricule de l'agent",
              hintText: "Ex: AGT-0012",
              prefixIcon: const Icon(Icons.badge_rounded),
              filled: true,
              fillColor: KioskColors.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 20 * scale),
          // Le bouton reste désactivé tant que le matricule est vide —
          // amélioration purement additive, aucune logique existante modifiée.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _matriculeController,
            builder: (context, value, _) {
              final canSubmit = value.text.trim().isNotEmpty;
              return ElevatedButton.icon(
                onPressed: canSubmit ? _submitEnroll : null,
                icon: const Icon(Icons.how_to_reg_rounded),
                label: const Text(
                  "VALIDER L'ENRÔLEMENT",
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Ubuntu'),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: KioskColors.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: KioskColors.outline.withOpacity(0.4),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Bouton icône discret pour la navigation (retour), remplace l'IconButton
/// nu par un cercle sobre cohérent avec le reste de l'interface admin.
class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KioskColors.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: KioskColors.textHigh),
        ),
      ),
    );
  }
}

/*import 'dart:async';
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
*/
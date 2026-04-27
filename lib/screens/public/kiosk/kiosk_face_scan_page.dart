import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '/global/controllers.dart';
import '/kernel/services/http_manager.dart';
import 'kiosk_components.dart';

class KioskFaceScanPage extends StatefulWidget {
  const KioskFaceScanPage({
    super.key,
    required this.onSuccess,
    required this.onCancel,
  });
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  @override
  State<KioskFaceScanPage> createState() => _KioskFaceScanPageState();
}

class _KioskFaceScanPageState extends State<KioskFaceScanPage> {
  CameraController? _controller;
  XFile? _capturedImage;
  String? _detectedMatricule;
  String? _detectedName;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  bool _isSuccess = false;
  bool _isFaceDetected = false;
  bool _showFlash = false;
  String _hint = "Positionnez votre visage";

  // --- NOUVELLES VARIABLES LIVE SCAN ---
  int _failedAttempts = 0;
  bool _eyesClosed = false;
  // --------------------------------------

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // Requis pour les yeux
      performanceMode: FaceDetectorMode.fast, // OPTIMISÉ : Plus rapide pour le clignement
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
      cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front),
      ResolutionPreset.medium, // OPTIMISÉ : Meilleure précision pour détecter les yeux
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});

    _startLiveStream();
  }

  void _startLiveStream() {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.startImageStream((image) {
        if (_isProcessingFrame || _isSuccess || _isCapturing) return;
        _isProcessingFrame = true;
        _processCameraImage(image);
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
            _isFaceDetected = false;
            _eyesClosed = false;
            _hint = "Positionnez votre visage";
          });
        }
      } else {
        final face = faces.first;
        if (mounted) {
          setState(() {
            _isFaceDetected = true;
            // Si on a déjà échoué 3 fois, on ne change plus le hint auto
            if (_failedAttempts < 3) {
               _hint = "Clignez des yeux pour scanner";
            } else {
               _hint = "Utilisez le bouton de capture";
            }
          });
        }

        // --- LOGIQUE DE CLIGNEMENT OPTIMISÉE ---
        if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
          double prob = (face.leftEyeOpenProbability! + face.rightEyeOpenProbability!) / 2;
          
          if (prob < 0.15 && !_eyesClosed) { // Seuil de fermeture
            _eyesClosed = true;
          } else if (prob > 0.5 && _eyesClosed) { // Seuil de réouverture pour validation
            // Détection d'un clignement complet (Fermé -> Ouvert)
            _eyesClosed = false;
            if (!_isCapturing && !_isSuccess) {
              _performCaptureAndVerify();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _performCaptureAndVerify({bool manual = false}) async {
    if (!_isFaceDetected || _controller == null || _isCapturing) return;

    if (mounted) {
      setState(() {
        _isCapturing = true;
        _hint = "Analyse biométrique...";
      });
    }

    // Effet visuel de flash réduit pour la rapidité
    if (mounted) {
      setState(() => _showFlash = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _showFlash = false);
      });
    }

    try {
      await _controller!.stopImageStream();
      final file = await _controller!.takePicture();
      final res = await faceRecognitionController.recognizeFaceFromImage(file);

      if (res != null && res['matricule'] != 'Inconnu') {
        if (mounted) {
          setState(() {
            _detectedMatricule = res['matricule']?.toString();
            _detectedName = res['name']?.toString();
            _capturedImage = file;
            _isSuccess = true;
            _failedAttempts = 0; // Reset
          });
        }
      } else {
        _failedAttempts++;
        if (mounted) {
          setState(() {
            _hint = "Inconnu ($_failedAttempts/3). Réessayez.";
          });
        }
        EasyLoading.showInfo("Visage non reconnu.");
        
        // Relancer le stream après l'échec
        _startLiveStream();
      }
    } catch (e) {
       _startLiveStream();
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final bytes = Uint8List.fromList(
        image.planes.fold<List<int>>(
          [],
          (buffer, plane) => buffer..addAll(plane.bytes),
        ),
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

  Future<void> _submit(String type) async {
    if (_detectedMatricule == null) return;
    EasyLoading.show(status: 'Pointage...');
    tagsController.attendanceType.value = type;
    tagsController.faceResult.value = _detectedMatricule!;
    tagsController.face.value = _capturedImage;
    final res = await HttpManager().checkPresence(key: type);
    EasyLoading.dismiss();
    if (res == 'success') {
      Get.back();
      widget.onSuccess();
    }
  }

  void _resetCamera() {
    setState(() {
      _isSuccess = false;
      _capturedImage = null;
      _detectedMatricule = null;
      _detectedName = null;
      _isFaceDetected = false;
      _failedAttempts = 0;
      _hint = "Positionnez votre visage";
    });
    _startLiveStream();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
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
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: KioskColors.background,
        body: Stack(
          children: [
            SafeArea(
              bottom: true,
              child: Column(
                children: [
                  _buildTopBar(),
                  SizedBox(height: 8 * scale),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _isSuccess ? "Agent Identifié" : _hint,
                      textAlign: TextAlign.center,
                      style: kioskTitle(context).copyWith(fontSize: 18 * scale),
                    ),
                  ),
                  if (_isSuccess) ...[
                    SizedBox(height: 12 * scale),
                    _buildMatriculeBadge(scale),
                  ],
                  const Spacer(),
                  _buildCameraCircle(scale),
                  const Spacer(),
                  // --- LE BOUTON MANUEL NE S'AFFICHE QU'APRÈS 3 ÉCHECS ---
                  if (!_isSuccess && _failedAttempts >= 3) ...[
                    _buildManualVerifyButton(scale)
                  ],
                  if (_isSuccess) ...[
                    Text(
                      "Sélectionnez votre action :",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: KioskColors.textMid,
                        fontFamily: 'Ubuntu',
                        fontWeight: FontWeight.w700,
                        fontSize: 13 * scale,
                      ),
                    ),
                    SizedBox(height: 12 * scale),
                    Flexible(
                      flex: 10,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildActionGrid(context, scale),
                      ),
                    ),
                  ],
                  SizedBox(height: 10 * scale),
                ],
              ),
            ),
            if (_showFlash)
              Positioned.fill(child: Container(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close)),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildManualVerifyButton(double scale) {
    final isEnabled = _isFaceDetected && !_isCapturing;
    return InkWell(
      onTap: isEnabled ? () => _performCaptureAndVerify(manual: true) : null,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 80.0,
        margin: EdgeInsets.only(bottom: 40 * scale),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isEnabled
                ? const [Color(0xFFB100FF), Color(0xFF4A00FF)]
                : const [Color(0xFF9E9E9E), Color(0xFF757575)],
          ),
          boxShadow: [
            BoxShadow(
              color: isEnabled
                  ? const Color(0xFF8F00FF)
                  : const Color(0xFF5F5F5F),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_rounded, color: Colors.white, size: 20 * scale),
            SizedBox(width: 12 * scale),
            Text(
              _isCapturing ? "Vérification..." : "Capture Manuelle",
              style: TextStyle(
                fontFamily: 'Ubuntu',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15 * scale,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatriculeBadge(double scale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: KioskColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KioskColors.success.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.face_retouching_natural_rounded,
                color: KioskColors.success,
                size: 22 * scale,
              ),
              SizedBox(width: 10 * scale),
              Text(
                _detectedMatricule ?? "Agent",
                style: TextStyle(
                  fontFamily: 'Ubuntu',
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.w800,
                  color: KioskColors.success,
                ),
              ),
            ],
          ),
          if (_detectedName != null) ...[
            SizedBox(height: 4 * scale),
            Text(
              _detectedName!.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Ubuntu',
                fontSize: 14 * scale,
                fontWeight: FontWeight.w600,
                color: KioskColors.textMid,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraCircle(double scale) {
    return Container(
      width: 260 * scale,
      height: 260 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _isSuccess ? KioskColors.success : KioskColors.primary,
          width: 6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: _isSuccess && _capturedImage != null
            ? Image.file(File(_capturedImage!.path), fit: BoxFit.cover)
            : (_controller != null && _controller!.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height,
                        height: _controller!.value.previewSize?.width,
                        child: CameraPreview(_controller!),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator())),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, double scale) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _ReferenceButton(
                icon: Icons.login_rounded,
                label: 'Entrée',
                color: Colors.green,
                secondaryColor: Colors.greenAccent,
                onTap: () => _submit('check-in'),
              ),
              _ReferenceButton(
                icon: Icons.logout_rounded,
                label: 'Départ',
                color: Colors.red,
                secondaryColor: Colors.redAccent,
                onTap: () => _submit('check-out'),
              ),
            ],
          ),
          Row(
            children: [
              _ReferenceButton(
                icon: Icons.build_circle_rounded,
                label: 'Maint. In',
                color: Colors.indigo,
                secondaryColor: Colors.indigoAccent,
                onTap: () => _submit('maintenance-in'),
              ),
              _ReferenceButton(
                icon: Icons.build_rounded,
                label: 'Maint. Out',
                color: Colors.deepOrange,
                secondaryColor: Colors.deepOrangeAccent,
                onTap: () => _submit('maintenance-out'),
              ),
            ],
          ),
          Row(
            children: [
              _ReferenceButton(
                icon: Icons.verified_user_rounded,
                label: 'Confirmation',
                color: Colors.blue,
                secondaryColor: Colors.blueAccent,
                onTap: () => _submit('confirmation'),
              ),

              _ReferenceButton(
                icon: Icons.refresh_rounded,
                label: 'Relancer',
                color: Colors.blueGrey.shade800,
                secondaryColor: Colors.blueGrey.shade400,
                onTap: _resetCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferenceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color secondaryColor;
  final VoidCallback onTap;

  const _ReferenceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.secondaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            height: 60 * scale,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 24 * scale),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10 * scale,
                        fontFamily: 'Ubuntu',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

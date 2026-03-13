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
import '/kernel/controllers/face_recognition_controller.dart';
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
  XFile? _capturedImage;
  String? _detectedMatricule;
  String? _detectedName;
  bool _isBusy = false;
  bool _isSuccess = false;
  bool _hasBlinked = false;
  bool _showFlash = false;
  String _hint = "Positionnez votre visage";
  
  // Logic for manual fallback
  int _failedAttempts = 0;
  bool _showManualButton = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.accurate),
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
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});

    _controller!.startImageStream((image) {
      if (_isBusy || _isSuccess || _showManualButton) return;
      _isBusy = true;
      _processCameraImage(image);
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        if (mounted) setState(() => _hint = "Visage non détecté");
      } else {
        final face = faces.first;
        
        if (!_hasBlinked) {
          if ((face.leftEyeOpenProbability ?? 1.0) < 0.4) {
            _hasBlinked = true;
          }
          if (mounted) setState(() => _hint = "Veuillez cligner des yeux");
        } else {
          await _performCaptureAndVerify();
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _performCaptureAndVerify({bool manual = false}) async {
    if (mounted) setState(() => _hint = manual ? "Vérification manuelle..." : "Analyse en cours...");
    
    if (mounted) {
      setState(() => _showFlash = true);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _showFlash = false);
      });
    }

    final file = await _controller!.takePicture();
    final res = await faceRecognitionController.recognizeFaceFromImage(file);
    
    if (res != null && res is Map && res['matricule'] != 'Inconnu') {
      if (mounted) {
        setState(() { 
          _detectedMatricule = res['matricule']?.toString();
          _detectedName = res['name']?.toString();
          _capturedImage = file; 
          _isSuccess = true; 
          _showManualButton = false;
        });
      }
      await _controller!.stopImageStream();
    } else {
      if (mounted) {
        setState(() {
          _hasBlinked = false;
          _failedAttempts++;
          if (_failedAttempts >= 2) {
            _showManualButton = true;
            _hint = "Échec automatique. Utilisez le bouton.";
          } else {
            _hint = "Visage inconnu, réessayez...";
          }
        });
      }
      if (manual) {
        EasyLoading.showError("Visage inconnu. Vérifiez de nouveau.");
      }
    }
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
      _hasBlinked = false;
      _failedAttempts = 0;
      _showManualButton = false;
      _hint = "Positionnez votre visage";
    });
    _initCamera();
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
                  Text(
                    _isSuccess ? "Identifié" : _hint, 
                    style: kioskTitle(context).copyWith(fontSize: 24 * scale)
                  ),
                  if (_isSuccess) ...[
                    SizedBox(height: 12 * scale),
                    _buildMatriculeBadge(scale),
                  ],
                  const Spacer(),
                  _buildCameraCircle(scale),
                  const Spacer(),
                  if (!_isSuccess) ...[
                    if (_showManualButton)
                      _buildManualVerifyButton(scale)
                    else
                      _buildLoader(scale),
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
                      )
                    ),
                  ],
                  SizedBox(height: 10 * scale),
                ],
              ),
            ),
            if (_showFlash) Positioned.fill(child: Container(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(children: [IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close)), const Spacer(), const KioskBadge(label: "SCAN BIOMÉTRIQUE")]),
    );
  }

  Widget _buildManualVerifyButton(double scale) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: ElevatedButton.icon(
        onPressed: () => _performCaptureAndVerify(manual: true),
        icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
        label: const Text("Vérifier manuellement"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: TextStyle(
            fontFamily: 'Ubuntu',
            fontWeight: FontWeight.w700,
            fontSize: 14 * scale,
          ),
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
              Icon(Icons.face_retouching_natural_rounded, color: KioskColors.success, size: 22 * scale),
              SizedBox(width: 10 * scale),
              Text(
                _detectedMatricule ?? "Agent",
                style: TextStyle(
                  fontFamily: 'Ubuntu',
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.w800,
                  color: KioskColors.success
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

  Widget _buildLoader(double scale) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16 * scale,
            height: 16 * scale,
            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
          ),
          SizedBox(width: 12 * scale),
          Text(
            "Analyse biométrique en cours...",
            style: TextStyle(
              fontFamily: 'Ubuntu',
              color: Colors.purple.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 13 * scale
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCircle(double scale) {
    return Container(
      width: 260 * scale, height: 260 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle, 
        border: Border.all(color: _isSuccess ? KioskColors.success : KioskColors.primary, width: 6),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
        ]
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
          Row(children: [
            _ReferenceButton(
              icon: Icons.login_rounded, 
              label: 'Check In', 
              color: Colors.green, 
              secondaryColor: Colors.greenAccent, 
              onTap: () => _submit('check-in')
            ), 
            _ReferenceButton(
              icon: Icons.logout_rounded, 
              label: 'Check Out', 
              color: Colors.red, 
              secondaryColor: Colors.redAccent, 
              onTap: () => _submit('check-out')
            )
          ]),
          Row(children: [
            _ReferenceButton(
              icon: Icons.verified_user_rounded, 
              label: 'Confirmation', 
              color: Colors.orange, 
              secondaryColor: Colors.orangeAccent, 
              onTap: () => _submit('confirmation')
            ), 
            _ReferenceButton(
              icon: Icons.build_circle_rounded, 
              label: 'Maintenance In',
              color: Colors.deepPurple, 
              secondaryColor: Colors.purpleAccent, 
              onTap: () => _submit('maintenance-in')
            )
          ]),
          Row(children: [
            _ReferenceButton(
              icon: Icons.hail_rounded, 
              label: 'Maintenance Out',
              color: Colors.pink, 
              secondaryColor: Colors.pinkAccent, 
              onTap: () => _submit('maintenance-out')
            ), 
            _ReferenceButton(
              icon: Icons.refresh_rounded, 
              label: 'Relancer', 
              color: Colors.blueGrey.shade800, 
              secondaryColor: Colors.blueGrey.shade400, 
              onTap: _resetCamera
            )
          ]),
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
    required this.onTap
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
                colors: [
                  color.withOpacity(0.18),
                  color.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [color, secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 18 * scale),
                  ),
                  SizedBox(width: 15 * scale),
                  Flexible(
                    child: Text(
                      label, 
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color.withOpacity(0.95), 
                        fontWeight: FontWeight.w900, 
                        fontSize: 11.5 * scale, 
                        fontFamily: 'Ubuntu',
                        letterSpacing: 0.2,
                      )
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

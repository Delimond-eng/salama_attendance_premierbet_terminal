import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '/global/controllers.dart';
import '/kernel/services/api.dart';
import '/kernel/services/http_manager.dart';
import 'kiosk_components.dart';
import 'kiosk_task_modal.dart';

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
  int _failedAttempts = 0;
  bool _isBlinking = false;
  bool _isConfirmingClosure = false;

  Offset? _blinkStartCenter;
  final double _headMoveThreshold =
      20.0; // pixels minimum de déplacement de la tête
  // Seuils et comptes pour robustesse avec caméras floues / basse résolution
  final double _closedEyeThreshold = 0.25; // <= considéré fermé
  final double _openEyeThreshold = 0.55; // >= considéré ouvert
  final int _framesRequired = 2; // nombre de frames consécutives requises
  int _closedFrames = 0;
  int _openFrames = 0;
  // Nouveaux marqueurs temporels pour détection de clignement plus robuste
  DateTime? _closedStartTime;
  DateTime? _lastBlinkTime;
  final Duration _minClosedDuration = const Duration(milliseconds: 60);
  final Duration _maxClosedDuration = const Duration(milliseconds: 1200);
  final Duration _minTimeBetweenCaptures = const Duration(milliseconds: 1300);
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
    ),
  );

  String get _client {
    final url = Api.baseUrl.toLowerCase();
    if (url.contains('electrocool')) return 'electrocool';
    if (url.contains('premierbet')) return 'premierbet';
    if (url.contains('chanimetal')) return 'chanimetal';
    if (url.contains('md')) return 'md';
    return 'default';
  }

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
      ResolutionPreset.medium,
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
      // reset blink authorization when starting a fresh live stream
      _isBlinking = false;
      _blinkStartCenter = null;
      _closedFrames = 0;
      _openFrames = 0;
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

      if (mounted) {
        setState(() {
          _isFaceDetected = faces.isNotEmpty;
        });

        if (faces.isNotEmpty) {
          final face = faces.first;
          // Pour electrocool : capture automatique dès le clignement des yeux
          // mais exiger un léger mouvement de tête entre la fermeture et la réouverture
          if (_client == 'electrocool' && !_isConfirmingClosure) {
            final leftEye = face.leftEyeOpenProbability ?? 1.0;
            final rightEye = face.rightEyeOpenProbability ?? 1.0;
            final Offset center = face.boundingBox.center;

            // Détection basée sur la durée de fermeture plutôt que sur un nombre
            // de frames consécutives. Plus robuste face à des taux de frame
            // variables et aux clignements rapides.
            final now = DateTime.now();
            if (leftEye <= _closedEyeThreshold &&
                rightEye <= _closedEyeThreshold) {
              // début ou continuation de la fermeture
              _closedStartTime ??= now;
              // mémoriser la position de la tête au début du clignement
              if (_blinkStartCenter == null) _blinkStartCenter = center;
            } else if (leftEye >= _openEyeThreshold &&
                rightEye >= _openEyeThreshold) {
              // réouverture après fermeture : vérifier durée
              if (_closedStartTime != null) {
                final closedDuration = now.difference(_closedStartTime!);
                final sinceLastBlink = _lastBlinkTime == null
                    ? const Duration(days: 365)
                    : now.difference(_lastBlinkTime!);

                if (closedDuration >= _minClosedDuration &&
                    closedDuration <= _maxClosedDuration &&
                    sinceLastBlink >= _minTimeBetweenCaptures) {
                  // reconnaissance autorisée : réinitialiser et capturer
                  _closedStartTime = null;
                  _blinkStartCenter = null;
                  _lastBlinkTime = now;
                  _performCaptureAndVerify();
                } else {
                  // échec ou clignement trop long/trop court -> reset
                  _closedStartTime = null;
                  _blinkStartCenter = null;
                }
              }
            } else {
              // état intermédiaire -> réinitialiser si nécessaire
              _closedStartTime = null;
              _blinkStartCenter = null;
            }
          } else if (_client != 'premierbet' &&
              _failedAttempts < 2 &&
              !_isConfirmingClosure) {
            final leftEye = face.leftEyeOpenProbability ?? 1.0;
            final rightEye = face.rightEyeOpenProbability ?? 1.0;

            if (leftEye < 0.2 && rightEye < 0.2) {
              _isBlinking = true;
            } else if (_isBlinking && leftEye > 0.6 && rightEye > 0.6) {
              _isBlinking = false;
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

  Future<void> _performCaptureAndVerify() async {
    if (_controller == null || _isCapturing) return;

    if (mounted) setState(() => _isCapturing = true);

    if (mounted) {
      setState(() => _showFlash = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _showFlash = false);
      });
    }

    try {
      await _controller!.stopImageStream();
      final file = await _controller!.takePicture();
      EasyLoading.show(status: 'Analyse biométrique...');
      final res = await faceRecognitionController.recognizeFaceFromImage(file);
      EasyLoading.dismiss();

      if (res != null && res['matricule'] != 'Inconnu') {
        if (mounted) {
          setState(() {
            _detectedMatricule = res['matricule']?.toString();
            _detectedName = res['name']?.toString();
            _capturedImage = file;
            _isSuccess = true;
            _failedAttempts = 0;
          });
        }

        if (_isConfirmingClosure) {
          _submit('maintenance-out');
        }
      } else {
        _failedAttempts++;
        EasyLoading.showInfo(
          (_client == 'premierbet' || _failedAttempts >= 2)
              ? "Identité non reconnue. Veuillez réessayer."
              : "Identité non reconnue. Réessayez le clignement des yeux.",
        );
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

  Future<void> _submit(String type, {bool openTasks = false}) async {
    if (_detectedMatricule == null) return;

    EasyLoading.show(status: 'Envoi...');
    tagsController.attendanceType.value = type;
    tagsController.faceResult.value = _detectedMatricule!;
    tagsController.face.value = _capturedImage;

    final res = await HttpManager().checkPresence(key: type);
    EasyLoading.dismiss();

    bool canProceed = false;
    String? serverMessage;
    String? specialMessage;

    if (res is Map && res['status'] == 'success') {
      canProceed = true;
      serverMessage = res['message']?.toString();
      final result = res['result'];
      if (result is Map && result.containsKey('special')) {
        final s = result['special'];
        if (s != null && s.toString().isNotEmpty) specialMessage = s.toString();
      }
    } else {
      // GESTION SPECIALE : Si maintenance déjà ouverte, on force l'accès aux tâches
      if (openTasks &&
          res != null &&
          res.toString().toLowerCase().contains("ouverte")) {
        canProceed = true;
      }
    }

    if (canProceed) {
      if (openTasks) {
        final result = await Get.bottomSheet(
          KioskTaskModal(
            matricule: _detectedMatricule!,
            capturedImage: _capturedImage,
          ),
          isScrollControlled: true,
          barrierColor: Colors.black54,
        );

        if (result == 'confirm-closure') {
          setState(() {
            _isConfirmingClosure = true;
            _isSuccess = false;
            _capturedImage = null;
            _detectedMatricule = null;
            _detectedName = null;
          });
          _startLiveStream();
        }
      } else {
        // Afficher modal succès avec message serveur et special si présent
        Get.dialog(
          WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              backgroundColor: Colors.white,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 12),
                  Text(
                    serverMessage ?? 'Opération réussie',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (specialMessage != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text(specialMessage)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          barrierDismissible: false,
        );

        // Fermer et notifier après un court délai
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) {
            _resetCamera();
            if (Get.isDialogOpen ?? false) Get.back();
          } else {
            if (Get.isDialogOpen ?? false) Get.back();
          }
        });
      }
    } else if (res != null) {
      EasyLoading.showError(res.toString());
    }
  }

  void _resetCamera() {
    setState(() {
      _isSuccess = false;
      _isConfirmingClosure = false;
      _capturedImage = null;
      _detectedMatricule = null;
      _detectedName = null;
      _isFaceDetected = false;
      _isCapturing = false;
      _isBlinking = false;
      _blinkStartCenter = null;
      _closedFrames = 0;
      _openFrames = 0;
      _closedStartTime = null;
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
      value: SystemUiOverlayStyle(
        statusBarColor: _isSuccess ? Colors.white : Colors.transparent,
        systemNavigationBarColor: _isSuccess ? Colors.white : Colors.black,
        systemNavigationBarIconBrightness: _isSuccess
            ? Brightness.dark
            : Brightness.light,
        statusBarIconBrightness: _isSuccess
            ? Brightness.dark
            : Brightness.light,
        statusBarBrightness: _isSuccess ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: _isSuccess && _capturedImage != null
                  ? Image.file(File(_capturedImage!.path), fit: BoxFit.cover)
                  : (_controller != null && _controller!.value.isInitialized
                        ? SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.previewSize!.height,
                                height: _controller!.value.previewSize!.width,
                                child: CameraPreview(_controller!),
                              ),
                            ),
                          )
                        : Container(color: Colors.black)),
            ),

            if (_isSuccess)
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.65)),
              ),

            // Masque Cyber Géométrique
            if (!_isSuccess)
              Positioned.fill(
                child: CustomPaint(
                  painter: FaceMaskOverlayPainter(
                    isFaceDetected: _isFaceDetected,
                  ),
                ),
              ),

            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (!_isSuccess) _buildTopBar(),

                  if (!_isSuccess) ...[
                    const Spacer(),
                    _buildHint(scale),
                    SizedBox(height: 20 * scale),
                    if (_client == 'premierbet' || _client=='md' || _failedAttempts >= 2 || _isConfirmingClosure)
                      _buildCaptureButton(scale),
                    SizedBox(height: 40 * scale),
                  ] else ...[
                    const Spacer(flex: 1),
                    _buildUserInfoHeader(scale),
                    const Spacer(flex: 1),
                    _buildGlassActionPanel(scale),
                  ],
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
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.black38,
            child: IconButton(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildUserInfoHeader(double scale) {
    return Column(
      children: [
        Container(
          width: 140 * scale,
          height: 140 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2ECC71), width: 4),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20)],
          ),
          child: ClipOval(
            child: Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _detectedName?.toUpperCase() ?? "AGENT",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20 * scale,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        Text(
          _detectedMatricule ?? "",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassActionPanel(double scale) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "CHOISISSEZ VOTRE OPÉRATION",
            style: TextStyle(
              fontSize: 12 * scale,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 25),
          _buildActionGrid(context, scale),
          const SizedBox(height: 15),
          if (_client == 'chanimetal' || _client == 'premierbet')
            Center(
              child: TextButton.icon(
                onPressed: _resetCamera,
                icon: const Icon(Icons.refresh, size: 12, color: Colors.blue),
                label: const Text("RELANCER LE SCAN"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blueGrey,
                  textStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 10 * scale,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHint(double scale) {
    String? msg;
    if (_isConfirmingClosure) {
      msg = "Confirmez votre identité pour clôturer";
    } else if (!_isFaceDetected) {
      msg = "Positionnez votre visage";
    } else if (_client == 'electrocool') {
      // Indication basée sur le nouvel algorithme de clignement
      if (_closedStartTime != null) {
        msg = "Clignez maintenant...";
      } else {
        msg = "Clignez des yeux pour valider";
      }
    } else if (_client == 'premierbet' || _failedAttempts >= 2) {
      msg = "Appuyez sur le bouton pour scanner";
    } else {
      msg = "Clignez des yeux pour valider";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _isConfirmingClosure ? Colors.orange : Colors.black54,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _client == 'electrocool' && _closedStartTime != null
                ? Icons.remove_red_eye
                : Icons.remove_red_eye,
            color: Colors.white,
            size: 16 * scale,
          ),
          const SizedBox(width: 8),
          Text(
            msg,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton(double scale) {
    return GestureDetector(
      onTap: _isCapturing ? null : _performCaptureAndVerify,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        height: 70 * scale,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2.0),
          gradient: const LinearGradient(
            colors: [Color(0xFF8A4FFF), Color(0xFF6366F1)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isCapturing)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(Icons.auto_awesome, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                _isCapturing
                    ? "ANALYSE..."
                    : (_isConfirmingClosure
                          ? "CONFIRMER LA CLÔTURE"
                          : "SCANNER LE VISAGE"),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, double scale) {
    List<Widget> rows = [];

    // Ligne 1 : Entrée / Sortie
    rows.add(
      Row(
        children: [
          _ReferenceButton(
            icon: Icons.login_rounded,
            label: 'Entrée',
            color: const Color(0xFF10B981),
            secondaryColor: const Color(0xFF34D399),
            onTap: () => _submit('check-in'),
          ),
          _ReferenceButton(
            icon: Icons.logout_rounded,
            label: 'Départ',
            color: const Color(0xFFEF4444),
            secondaryColor: const Color(0xFFF87171),
            onTap: () => _submit('check-out'),
          ),
        ],
      ),
    );

    rows.add(const SizedBox(height: 12));

    // Ligne 2 : Maintenance / Tâches
    if (_client == 'electrocool') {
      rows.add(
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
              color: const Color(0xFFF59E0B),
              secondaryColor: const Color(0xFFFBBF24),
              onTap: () => _submit('maintenance-out'),
            ),
          ],
        ),
      );
      rows.add(const SizedBox(height: 12));
      rows.add(
        Row(
          children: [
            _ReferenceButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Confirmation',
              color: Colors.blue,
              secondaryColor: Colors.lightBlueAccent,
              onTap: () => _submit('confirmation'),
            ),
            _ReferenceButton(
              icon: Icons.refresh_rounded,
              label: 'Relancer',
              color: const Color(0xFF4D5B78),
              secondaryColor: const Color(0xFF8A96AE),
              onTap: _resetCamera,
            ),
          ],
        ),
      );
    } else if (_client == 'chanimetal') {
      rows.add(
        Row(
          children: [
            _ReferenceButton(
              icon: Icons.assignment_rounded,
              label: 'Maint. & Tâches',
              color: const Color(0xFF8B5CF6),
              secondaryColor: const Color(0xFFA78BFA),
              onTap: () => _submit('maintenance-in', openTasks: true),
            ),
            _ReferenceButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Confirmation',
              color: const Color(0xFF6B7280),
              secondaryColor: const Color(0xFF9CA3AF),
              onTap: () => _submit('Confirmation'),
            ),
          ],
        ),
      );
    } else if (_client == 'premierbet') {
      rows.add(
        Row(
          children: [
            _ReferenceButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Confirmation',
              color: Colors.blue,
              secondaryColor: Colors.lightBlueAccent,
              onTap: () => _submit('Confirmation'),
            ),
            _ReferenceButton(
              icon: Icons.refresh_rounded,
              label: 'Relancer',
              color: const Color(0xFF4D5B78),
              secondaryColor: const Color(0xFF8A96AE),
              onTap: _resetCamera,
            ),
          ],
        ),
      );
    }
    else{
      rows.add(
        Row(
          children: [
            _ReferenceButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Confirmation',
              color: Colors.blue,
              secondaryColor: Colors.lightBlueAccent,
              onTap: () => _submit('Confirmation'),
            ),
            _ReferenceButton(
              icon: Icons.refresh_rounded,
              label: 'Relancer',
              color: const Color(0xFF4D5B78),
              secondaryColor: const Color(0xFF8A96AE),
              onTap: _resetCamera,
            ),
          ],
        ),
      );
    }

    return Column(children: rows);
  }
}

class FaceMaskOverlayPainter extends CustomPainter {
  final bool isFaceDetected;

  FaceMaskOverlayPainter({required this.isFaceDetected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final ovalWidth = size.width * 0.72;
    final ovalHeight = ovalWidth * 1.35;
    final center = Offset(size.width / 2, size.height * 0.42);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // 1. Découpe ovale
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addOval(ovalRect),
      ),
      paint,
    );

    // 2. Bordure lumineuse
    final borderPaint = Paint()
      ..color = isFaceDetected
          ? const Color(0xFF2ECC71)
          : Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    _drawDashedOval(canvas, ovalRect, borderPaint);

    // 3. Maillage Cyber Géométrique (Nodes & Mesh)
    final meshColor = isFaceDetected
        ? const Color(0xFF2ECC71)
        : Colors.white.withOpacity(0.18);
    final meshPaint = Paint()
      ..color = meshColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    _drawFaceMesh(canvas, center, ovalWidth, ovalHeight, meshPaint);
  }

  void _drawFaceMesh(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
  ) {
    final double w = width * 0.5;
    final double h = height * 0.5;

    // Définition des points faciaux (Structure cyber inspirée de l'image)
    final points = [
      center.translate(0, -h * 0.85), // 0: Front haut
      center.translate(-w * 0.4, -h * 0.65), // 1: Front gauche
      center.translate(w * 0.4, -h * 0.65), // 2: Front droit
      center.translate(-w * 0.7, -h * 0.15), // 3: Tempe gauche
      center.translate(w * 0.7, -h * 0.15), // 4: Tempe droite
      center.translate(-w * 0.5, h * 0.3), // 5: Pommette gauche
      center.translate(w * 0.5, h * 0.3), // 6: Pommette droite
      center.translate(0, h * 0.1), // 7: Nez centre
      center.translate(0, h * 0.9), // 8: Menton
      center.translate(-w * 0.35, h * 0.75), // 9: Machoire gauche
      center.translate(w * 0.35, h * 0.75), // 10: Machoire droite
      center.translate(-w * 0.2, h * 0.45), // 11: Bouche gauche
      center.translate(w * 0.2, h * 0.45), // 12: Bouche droite
    ];

    // Connexions triangulées
    final List<List<int>> connections = [
      [0, 1],
      [0, 2],
      [1, 2],
      [1, 3],
      [2, 4],
      [3, 5],
      [4, 6],
      [5, 7],
      [6, 7],
      [5, 9],
      [6, 10],
      [9, 8],
      [10, 8],
      [11, 12],
      [7, 11],
      [7, 12],
      [11, 8],
      [12, 8],
      [3, 1],
      [4, 2],
      [0, 7],
      [3, 7],
      [4, 7],
      [5, 11],
      [6, 12],
    ];

    for (var conn in connections) {
      canvas.drawLine(points[conn[0]], points[conn[1]], paint);
    }

    // Nodes (Points d'ancrage)
    final dotPaint = Paint()
      ..color = paint.color.withOpacity(isFaceDetected ? 1.0 : 0.4)
      ..style = PaintingStyle.fill;

    for (var p in points) {
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 3, height: 3),
        dotPaint,
      );
    }
  }

  void _drawDashedOval(Canvas canvas, Rect rect, Paint paint) {
    const double dashWidth = 15;
    const double dashSpace = 12;
    final path = Path()..addOval(rect);
    for (final pathMetric in path.computeMetrics()) {
      double distance = 0;
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant FaceMaskOverlayPainter oldDelegate) =>
      oldDelegate.isFaceDetected != isFaceDetected;
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
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24 * scale),
          child: Container(
            height: 105 * scale,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24 * scale),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -10 * scale,
                  top: -10 * scale,
                  child: Icon(
                    icon,
                    size: 80 * scale,
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 22 * scale,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11 * scale,
                          letterSpacing: 1,
                        ),
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

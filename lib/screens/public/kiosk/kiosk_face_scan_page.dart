import 'dart:async';
import 'dart:io';
import 'dart:ui';
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
  String _hint = "Positionnez votre visage dans le cadre";

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
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
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _performCaptureAndVerify() async {
    if (_controller == null || _isCapturing) return;

    if (mounted) {
      setState(() {
        _isCapturing = true;
      });
    }

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
          });
        }
      } else {
        EasyLoading.showInfo("Visage non reconnu.");
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
      _isCapturing = false;
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
        statusBarIconBrightness: _isSuccess ? Brightness.dark : Brightness.light,
        statusBarBrightness: _isSuccess ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: _isSuccess ? Colors.white : Colors.black,
        systemNavigationBarIconBrightness:
            _isSuccess ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Background (Camera Preview or Captured Image)
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

            // 2. Dim effect if Success
            if (_isSuccess)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.65),
                ),
              ),

            // 3. Face Mask Overlay
            if (!_isSuccess)
              Positioned.fill(
                child: CustomPaint(
                  painter: FaceMaskPainter(),
                ),
              ),

            // 4. UI Layer
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Only show top bar (dismiss) if NOT success
                  if (!_isSuccess) _buildTopBar(),
                  
                  if (!_isSuccess) ...[
                    const Spacer(),
                    _buildHint(scale),
                    SizedBox(height: 20 * scale),
                    _buildCaptureButton(scale),
                    SizedBox(height: 40 * scale),
                  ] else ...[
                    const Spacer(flex: 2),
                    _buildCircularAvatar(scale),
                    const SizedBox(height: 24),
                    _buildUserInfoRow(scale),
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

  Widget _buildCircularAvatar(double scale) {
    return Container(
      width: 170 * scale,
      height: 170 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2ECC71), width: 6),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: ClipOval(
        child: Image.file(
          File(_capturedImage!.path),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildUserInfoRow(double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Badge matricule
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Text(
            _detectedMatricule ?? "",
            style: TextStyle(
              fontSize: 14 * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Text(
            _detectedName?.toUpperCase() ?? "AGENT",
            style: TextStyle(
              fontSize: 14 * scale,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2ECC71),
              letterSpacing: 1,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 10)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassActionPanel(double scale) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 35, 20, 50),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "SÉLECTIONNEZ UNE ACTION",
            style: TextStyle(
              fontSize: 13 * scale,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 30),
          _buildActionGrid(context, scale),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _resetCamera,
            icon: const Icon(Icons.refresh, color: Colors.blue, size: 18),
            label: Text(
              "Recommencer le scan",
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 13 * scale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint(double scale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        _isFaceDetected ? "Visage détecté" : _hint,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14 * scale,
          fontWeight: FontWeight.w500,
        ),
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
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              else
                const Icon(Icons.auto_awesome, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                _isCapturing ? "Analyse..." : "Scanner le visage",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w600,
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
    return Column(
      children: [
        Row(
          children: [
            _ReferenceButton(
              icon: Icons.login_rounded,
              label: 'Entrée',
              color: const Color(0xFF10B981),
              secondaryColor: const Color(0xFF059669),
              onTap: () => _submit('check-in'),
            ),
            _ReferenceButton(
              icon: Icons.logout_rounded,
              label: 'Départ',
              color: const Color(0xFFEF4444),
              secondaryColor: const Color(0xFFDC2626),
              onTap: () => _submit('check-out'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ReferenceButton(
              icon: Icons.build_circle_rounded,
              label: 'Maint. In',
              color: const Color(0xFF3B82F6),
              secondaryColor: const Color(0xFF2563EB),
              onTap: () => _submit('maintenance-in'),
            ),
            _ReferenceButton(
              icon: Icons.build_rounded,
              label: 'Maint. Out',
              color: const Color(0xFFF59E0B),
              secondaryColor: const Color(0xFFD97706),
              onTap: () => _submit('maintenance-out'),
            ),
          ],
        ),
      ],
    );
  }
}

class FaceMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final ovalWidth = size.width * 0.72;
    final ovalHeight = ovalWidth * 1.35;
    final center = Offset(size.width / 2, size.height * 0.42);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addOval(ovalRect),
      ),
      paint,
    );

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    _drawDashedOval(canvas, ovalRect, borderPaint);

    // Draw symmetry lines (Cross)
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, ovalRect.top),
      Offset(center.dx, ovalRect.bottom),
      linePaint,
    );

    // Horizontal line
    canvas.drawLine(
      Offset(ovalRect.left, center.dy),
      Offset(ovalRect.right, center.dy),
      linePaint,
    );

    // Draw Scale (Ladder/Graduation)
    final ladderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double stepSize = 12.0;
    const double tickWidth = 8.0;
    
    // Vertical Ladder
    double currentY = ovalRect.top + stepSize;
    while (currentY < ovalRect.bottom) {
      if ((currentY - center.dy).abs() > 5) { // Skip center
        canvas.drawLine(
          Offset(center.dx - tickWidth / 2, currentY),
          Offset(center.dx + tickWidth / 2, currentY),
          ladderPaint,
        );
      }
      currentY += stepSize;
    }

    // Horizontal Ladder
    double currentX = ovalRect.left + stepSize;
    while (currentX < ovalRect.right) {
       if ((currentX - center.dx).abs() > 5) { // Skip center
        canvas.drawLine(
          Offset(currentX, center.dy - tickWidth / 2),
          Offset(currentX, center.dy + tickWidth / 2),
          ladderPaint,
        );
      }
      currentX += stepSize;
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        padding: const EdgeInsets.symmetric(horizontal: 7.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 70 * scale,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28 * scale),
                const SizedBox(height: 6),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11 * scale,
                    letterSpacing: 1.2,
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

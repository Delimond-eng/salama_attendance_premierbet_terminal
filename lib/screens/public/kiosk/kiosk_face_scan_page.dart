import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '/global/controllers.dart';
import '/kernel/services/http_manager.dart';
import 'kiosk_components.dart';

const _kioskDarkStatusBarStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

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
  static const EventChannel _volumeKeyChannel = EventChannel(
    'salama/volume_keys',
  );

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;
  String? _detectedMatricule;
  StreamSubscription<dynamic>? _volumeKeySubscription;
  bool _volumeCaptureInProgress = false;

  bool get _isRecognized =>
      _detectedMatricule != null && _detectedMatricule != 'Inconnu';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), _initCamera);
    _listenVolumeUpCapture();
  }

  void _listenVolumeUpCapture() {
    _volumeKeySubscription = _volumeKeyChannel.receiveBroadcastStream().listen(
      (event) async {
        if (event != 'volume_up') return;
        if (!mounted || _capturedImage != null || _volumeCaptureInProgress) {
          return;
        }

        _volumeCaptureInProgress = true;
        try {
          await _captureAndAnalyze();
        } finally {
          _volumeCaptureInProgress = false;
        }
      },
      onError: (error) {
        debugPrint('Volume key stream error: $error');
      },
    );
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    await _controller?.dispose();

    var selectedIndex = tagsController.cameraIndex.value;
    if (selectedIndex < 0 || selectedIndex >= cameras.length) {
      selectedIndex = 0;
      tagsController.cameraIndex.value = 0;
    }

    _controller = CameraController(
      cameras[selectedIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      _initializeControllerFuture = _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Erreur Camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    final cameras = await availableCameras();
    if (cameras.length < 2) return;

    tagsController.cameraIndex.value =
        (tagsController.cameraIndex.value + 1) % cameras.length;
    await _initCamera();
  }

  Future<void> _captureAndAnalyze() async {
    try {
      final image = await _controller?.takePicture();
      if (image == null) return;

      setState(() {
        _capturedImage = image;
        _detectedMatricule = null;
      });

      final matricule = await faceRecognitionController.recognizeFaceFromImage(
        image,
      );

      if (!mounted) return;
      setState(() {
        _detectedMatricule = matricule;
      });
    } catch (e) {
      debugPrint('Erreur capture/analyse: $e');
    }
  }

  Future<void> _submitPresence() async {
    if (_detectedMatricule == null || _capturedImage == null) return;

    EasyLoading.show(status: 'Envoi...');
    tagsController.faceResult.value = _detectedMatricule!;
    tagsController.face.value = _capturedImage;

    final res = await HttpManager().checkPresence(
      key: tagsController.attendanceType.value,
    );

    EasyLoading.dismiss();
    if (!mounted) return;

    if (res == 'success') {
      Get.back();
      widget.onSuccess();
    } else {
      EasyLoading.showInfo(
        res.toString(),
        duration: const Duration(seconds: 4),
      );
      setState(() {
        _capturedImage = null;
        _detectedMatricule = null;
      });
    }
  }

  @override
  void dispose() {
    _volumeKeySubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _kioskDarkStatusBarStyle,
      child: Scaffold(
        backgroundColor: KioskColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: KioskColors.textHigh,
                      ),
                    ),
                    const Spacer(),
                    Obx(
                      () => KioskBadge(
                        label: tagsController.attendanceType.value.toUpperCase(),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20 * scale),
                Text(
                  'Verification faciale',
                  textAlign: TextAlign.center,
                  style: kioskTitle(context).copyWith(fontSize: 28 * scale),
                ),
                SizedBox(height: 10 * scale),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _detectedMatricule == null
                      ? Text(
                          'Cadrez le visage puis capturez.',
                          textAlign: TextAlign.center,
                          style: kioskBody(
                            context,
                          ).copyWith(fontSize: 13.5 * scale),
                        )
                      : Wrap(
                          spacing: 8 * scale,
                          runSpacing: 8 * scale,
                          alignment: WrapAlignment.center,
                          children: [
                            _MatriculeBadge(
                              label: _isRecognized
                                  ? 'MATRICULE: $_detectedMatricule'
                                  : 'VISAGE INCONNU',
                              isSuccess: _isRecognized,
                            ),
                          ],
                        ),
                ),
                const Spacer(),
                Column(
                  children: [
                    Container(
                      width: 340 * scale,
                      height: 340 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: KioskColors.primary, width: 4),
                      ),
                      child: ClipOval(child: _buildCameraPreview()),
                    ),
                  ],
                ),
                const Spacer(),
                if (_capturedImage == null)
                  Row(
                    children: [
                      Expanded(
                        child: _BottomActionButton(
                          icon: Icons.flip_camera_ios_rounded,
                          label: 'Camera',
                          color: const Color(0xFF4C83FF),
                          onTap: _switchCamera,
                        ),
                      ),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        child: _BottomActionButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Capturer',
                          color: KioskColors.primary,
                          isPrimary: true,
                          onTap: _captureAndAnalyze,
                        ),
                      ),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        child: _BottomActionButton(
                          icon: Icons.close_rounded,
                          label: 'Annuler',
                          color: const Color(0xFF8C96AB),
                          onTap: widget.onCancel,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _BottomActionButton(
                          icon: Icons.refresh_rounded,
                          label: 'Reprendre',
                          color: KioskColors.textMid,
                          onTap: () => setState(() {
                            _capturedImage = null;
                            _detectedMatricule = null;
                          }),
                        ),
                      ),
                      if (_isRecognized) ...[
                        SizedBox(width: 10 * scale),
                        Expanded(
                          child: _BottomActionButton(
                            icon: Icons.check_rounded,
                            label: 'Valider',
                            color: KioskColors.success,
                            isPrimary: true,
                            onTap: _submitPresence,
                          ),
                        ),
                      ],
                    ],
                  ),
                SizedBox(height: 48 * scale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_capturedImage != null) {
      return Image.file(File(_capturedImage!.path), fit: BoxFit.cover);
    }

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            _controller != null) {
          return FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.previewSize?.height,
              height: _controller!.value.previewSize?.width,
              child: CameraPreview(_controller!),
            ),
          );
        }

        return const Center(
          child: CircularProgressIndicator(color: KioskColors.primary),
        );
      },
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final scale = kioskScale(context);
    return SizedBox(
      height: 58 * scale,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18 * scale),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Ubuntu',
            fontWeight: FontWeight.w700,
            fontSize: 12.5 * scale,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * scale),
          ),
          shadowColor: color.withValues(alpha: isPrimary ? 0.25 : 0.12),
        ),
      ),
    );
  }
}

class _MatriculeBadge extends StatelessWidget {
  const _MatriculeBadge({required this.label, required this.isSuccess});

  final String label;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? KioskColors.success : KioskColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontFamily: 'Ubuntu',
          fontSize: 12 * kioskScale(context),
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

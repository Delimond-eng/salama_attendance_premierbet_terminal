import 'dart:io';
import 'dart:async';

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
  static const EventChannel _volumeKeyChannel = EventChannel(
    'salama/volume_keys',
  );

  final TextEditingController _matriculeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _enrollFormKey = GlobalKey();
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;
  StreamSubscription<dynamic>? _volumeKeySubscription;
  bool _volumeCaptureInProgress = false;

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
          await _capturePhoto();
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
      debugPrint("Erreur camera: $e");
    }
  }

  Future<void> _switchCamera() async {
    final cameras = await availableCameras();
    if (cameras.length < 2) return;

    tagsController.cameraIndex.value =
        (tagsController.cameraIndex.value + 1) % cameras.length;
    await _initCamera();
  }

  Future<void> _capturePhoto() async {
    final image = await _controller?.takePicture();
    if (!mounted || image == null) return;

    setState(() => _capturedImage = image);
    await _scrollToEnrollForm();
  }

  Future<void> _submitEnroll() async {
    if (_matriculeController.text.trim().isEmpty) {
      EasyLoading.showInfo("Matricule requis");
      return;
    }
    if (_capturedImage == null) {
      EasyLoading.showInfo("Capture photo requise");
      return;
    }

    EasyLoading.show(status: 'Enrolement...');
    tagsController.face.value = _capturedImage;

    await faceRecognitionController.addKnownFaceFromImage(
      _matriculeController.text.trim(),
      _capturedImage!,
    );
    final res = await HttpManager().enrollAgent(
      _matriculeController.text.trim(),
    );
    EasyLoading.dismiss();

    if (!mounted) return;
    if (res == "success") {
      Get.back();
      widget.onSuccess();
    } else {
      EasyLoading.showError(res.toString());
    }
  }

  Future<void> _scrollToEnrollForm() async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted || _capturedImage == null) return;

    final formContext = _enrollFormKey.currentContext;
    if (formContext == null) return;
    if (!formContext.mounted) return;

    await Scrollable.ensureVisible(
      formContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
  }

  @override
  void dispose() {
    _volumeKeySubscription?.cancel();
    _controller?.dispose();
    _matriculeController.dispose();
    _scrollController.dispose();
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
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const KioskBadge(label: "ENROLLEMENT"),
                ],
              ),
              SizedBox(height: 18 * scale),
              Text(
                "Nouvel enrolement",
                textAlign: TextAlign.center,
                style: kioskTitle(context).copyWith(fontSize: 28 * scale),
              ),
              SizedBox(height: 8 * scale),
              Text(
                "Capturez le visage puis assignez un matricule.",
                textAlign: TextAlign.center,
                style: kioskBody(context).copyWith(fontSize: 13.5 * scale),
              ),
              SizedBox(height: 24 * scale),
              Center(
                child: Container(
                  width: 300 * scale,
                  height: 300 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: KioskColors.primary, width: 4),
                  ),
                  child: ClipOval(child: _buildPreview()),
                ),
              ),
              SizedBox(height: 22 * scale),
              if (_capturedImage == null)
                Row(
                  children: [
                    Expanded(
                      child: _EnrollActionButton(
                        icon: Icons.flip_camera_ios_rounded,
                        label: "Camera",
                        color: const Color(0xFF4C83FF),
                        onTap: _switchCamera,
                      ),
                    ),
                    SizedBox(width: 10 * scale),
                    Expanded(
                      child: _EnrollActionButton(
                        icon: Icons.camera_alt_rounded,
                        label: "Capturer",
                        color: KioskColors.primary,
                        isPrimary: true,
                        onTap: _capturePhoto,
                      ),
                    ),
                  ],
                )
              else ...[
                KioskCard(
                  key: _enrollFormKey,
                  padding: EdgeInsets.all(16 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Matricule de l'agent",
                        style: kioskCaption(context).copyWith(
                          color: KioskColors.textMid,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      TextField(
                        controller: _matriculeController,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(
                          color: KioskColors.textHigh,
                          fontSize: 15.5 * scale,
                          fontFamily: 'Ubuntu',
                          fontWeight: FontWeight.w600,
                        ),

                        decoration: InputDecoration(
                          labelText: "Matricule",
                          labelStyle: TextStyle(
                            color: KioskColors.textMid,
                            fontSize: 12.0 * scale,
                            fontFamily: 'Ubuntu',
                            fontWeight: FontWeight.w500,
                          ),
                          hintStyle: TextStyle(
                            color: KioskColors.textLow,
                            fontSize: 12.0 * scale,
                            fontFamily: 'Ubuntu',
                            fontWeight: FontWeight.w400,
                          ),
                          hintText: "Ex: AGT-0012",
                          filled: true,
                          fillColor: KioskColors.surfaceMuted,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16 * scale,
                            vertical: 14 * scale,
                          ),
                          prefixIcon: Icon(
                            Icons.badge_rounded,
                            color: KioskColors.accent,
                            size: 20 * scale,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10 * scale),
                            borderSide: BorderSide(
                              color: KioskColors.outline.withValues(alpha: 0.9),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16 * scale),
                            borderSide: BorderSide(
                              color: KioskColors.outline.withValues(alpha: 0.9),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16 * scale),
                            borderSide: const BorderSide(
                              color: KioskColors.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 14 * scale),
                      _EnrollActionButton(
                        isPrimary: true,
                        label: "Valider l'enrolement",
                        icon: Icons.how_to_reg_rounded,
                        color: KioskColors.primaryDark,
                        onTap: _submitEnroll,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16 * scale),
                KioskGhostButton(
                  label: "Reprendre la photo",
                  icon: Icons.refresh_rounded,
                  onPressed: () => setState(() {
                    _capturedImage = null;
                    _matriculeController.clear();
                  }),
                ),
              ],
                SizedBox(height: 18 * scale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
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

class _EnrollActionButton extends StatelessWidget {
  const _EnrollActionButton({
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
      height: 56 * scale,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18 * scale),
        label: Text(
          label,
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
          shadowColor: color.withValues(alpha: isPrimary ? 0.24 : 0.12),
        ),
      ),
    );
  }
}

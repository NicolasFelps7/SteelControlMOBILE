import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';

class FaceAuthScreen extends StatefulWidget {
  const FaceAuthScreen({required this.controller, this.registrationToken, this.userId, super.key});

  final AppController controller;
  final String? registrationToken;
  final int? userId;

  bool get isRegistration => registrationToken?.isNotEmpty == true || userId != null;

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  CameraController? _camera;
  String _title = 'Preparando a câmera';
  String _instruction = 'Mantenha o tablet na altura dos olhos.';
  double _progress = 0;
  bool _busy = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _camera = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camera!.initialize();
      if (!mounted) return;
      setState(() {
        _busy = false;
        final strings = AppStrings.of(context);
        _title = widget.isRegistration ? strings.get('biometricRegister') : strings.get('faceRecognition');
        _instruction = strings.get('centerFace');
      });
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (mounted && !_busy && !_finished) await _start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        final strings = AppStrings.of(context);
        _title = strings.get('cameraUnavailable');
        _instruction = strings.get('cameraPermission');
      });
    }
  }

  Future<File> _capture() async {
    final file = await _camera!.takePicture();
    return File(file.path);
  }

  Future<void> _start() async {
    if (_busy || _camera?.value.isInitialized != true) return;
    final strings = AppStrings.of(context);
    setState(() => _busy = true);

    try {
      if (widget.isRegistration) {
        await _registrationFlow();
      } else {
        await _loginFlow();
      }
    } on ApiException catch (exception) {
      _setError(exception.message);
    } catch (_) {
      _setError(strings.get('faceValidationFailed'));
    }
  }

  Future<void> _registrationFlow() async {
    final strings = AppStrings.of(context);
    _step(strings.get('lookCamera'), strings.get('keepFaceStill'), .35);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final image = await _capture();
    final analysis = await widget.controller.auth.analyzeFace(image);

    if (analysis['pronto'] != true) {
      throw ApiException('${analysis['orientacao'] ?? strings.get('adjustPosition')}');
    }

    _step(strings.get('qualityConfirmed'), strings.get('protectingBiometrics'), .78);
    if (widget.userId != null) {
      await widget.controller.companyApi.registerUserFace(widget.userId!, image);
    } else {
      await widget.controller.auth.registerFace(image, widget.registrationToken!);
    }
    _success(strings.get('biometricsRegistered'), strings.get('biometricsLinkedOnce'));
  }

  Future<void> _loginFlow() async {
    final strings = AppStrings.of(context);
    _step(strings.get('firstPosition'), strings.get('lookCameraSentence'), .18);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final first = await _capture();
    final firstAnalysis = await widget.controller.auth.analyzeFace(first);
    if (firstAnalysis['pronto'] != true) {
      throw ApiException('${firstAnalysis['orientacao'] ?? strings.get('centerFace')}');
    }

    _step(strings.get('liveness'), strings.get('turnHeadSlightly'), .45);
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    final liveness = await _capture();
    final motionAnalysis = await widget.controller.auth.analyzeFace(liveness);
    final yaw = _number((motionAnalysis['pose'] as Map?)?['yaw']);
    if (yaw.abs() < 10) {
      throw ApiException(strings.get('movementNotDetected'));
    }

    _step(strings.get('returnCenter'), strings.get('lookAgain'), .72);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final finalImage = await _capture();
    final finalAnalysis = await widget.controller.auth.analyzeFace(finalImage);
    if (finalAnalysis['pronto'] != true) {
      throw ApiException('${finalAnalysis['orientacao'] ?? strings.get('returnFront')}');
    }

    _step(strings.get('verifyingIdentity'), strings.get('confirmingAccess'), .90);
    await widget.controller.loginWithFace(finalImage, liveness);
    _success(strings.get('identityConfirmed'), strings.get('welcomeEnvironment'));
  }

  void _step(String title, String instruction, double progress) {
    if (!mounted) return;
    setState(() {
      _title = title;
      _instruction = instruction;
      _progress = progress;
    });
  }

  void _success(String title, String instruction) {
    if (!mounted) return;
    setState(() {
      _title = title;
      _instruction = instruction;
      _progress = 1;
      _busy = false;
      _finished = true;
    });

    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.pop(context, true);
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _title = AppStrings.of(context).get('validationUnable');
      _instruction = message;
      _progress = 0;
      _busy = false;
    });
  }

  double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07101F),
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text(widget.isRegistration ? strings.get('faceRegister') : strings.get('faceIdTitle')),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tablet = constraints.maxWidth >= 700;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(tablet ? 40 : 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: tablet ? 880 : 520),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(tablet ? 36 : 22),
                      child: Column(
                        children: [
                          Text(strings.translate(_title), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(strings.translate(_instruction), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SteelColors.muted)),
                          const SizedBox(height: 24),
                          Container(
                            constraints: BoxConstraints(maxHeight: tablet ? 480 : 520),
                            decoration: BoxDecoration(color: const Color(0xFF07101F), borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFF253451))),
                            padding: const EdgeInsets.all(16),
                            child: AspectRatio(
                              aspectRatio: tablet ? 4 / 3 : 3 / 4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_camera?.value.isInitialized == true) CameraPreview(_camera!) else Container(color: const Color(0xFF111B2E), child: const Center(child: Icon(Icons.face_rounded, size: 90, color: SteelColors.muted))),
                                    IgnorePointer(child: CustomPaint(painter: _FaceGuidePainter(success: _finished))),
                                    Positioned(left: 18, right: 18, bottom: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xCC07101F), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_finished ? Icons.verified_rounded : Icons.center_focus_strong_rounded, color: _finished ? SteelColors.success : Colors.white, size: 18), const SizedBox(width: 8), Flexible(child: Text(strings.get(_finished ? 'protectedIdentity' : 'positionFace'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8))) ]))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          LinearProgressIndicator(value: _progress, minHeight: 7, borderRadius: BorderRadius.circular(10)),
                          const SizedBox(height: 22),
                          if (_busy) Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 12), Text(strings.get('automaticValidation'), style: const TextStyle(fontWeight: FontWeight.w700))]) else if (!_finished) FilledButton.icon(onPressed: _start, icon: const Icon(Icons.refresh_rounded), label: Text(strings.get('retry'))),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shield_outlined, size: 17, color: SteelColors.muted),
                              const SizedBox(width: 7),
                              Flexible(child: Text(strings.get('imagesAuthOnly'), style: const TextStyle(color: SteelColors.muted, fontSize: 12))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter({required this.success});
  final bool success;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = const Color(0x88030A16);
    final guide = Rect.fromCenter(center: Offset(size.width / 2, size.height * .47), width: size.width * .56, height: size.height * .72);
    final oval = Path()..addOval(guide);
    final mask = Path()..addRect(Offset.zero & size)..addPath(oval, Offset.zero)..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, overlay);
    final outline = Paint()
      ..color = success ? SteelColors.success : const Color(0xFF60A5FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawOval(guide, outline);
    final corner = Paint()
      ..color = success ? SteelColors.success : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const length = 24.0;
    for (final point in [guide.topLeft, guide.topRight, guide.bottomLeft, guide.bottomRight]) {
      final sx = point.dx < size.width / 2 ? 1.0 : -1.0;
      final sy = point.dy < size.height / 2 ? 1.0 : -1.0;
      canvas.drawLine(point, point + Offset(sx * length, 0), corner);
      canvas.drawLine(point, point + Offset(0, sy * length), corner);
    }
  }

  @override
  bool shouldRepaint(_FaceGuidePainter oldDelegate) => oldDelegate.success != success;
}

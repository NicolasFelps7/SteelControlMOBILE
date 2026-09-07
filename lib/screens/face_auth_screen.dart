import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';

class FaceAuthScreen extends StatefulWidget {
  FaceAuthScreen({
    required this.controller,
    String? registrationToken,
    Object? registrationId,
    this.userId,
    this.captureOnly = false,
    super.key,
  }) : registrationId = registrationId?.toString() ?? registrationToken;

  final AppController controller;
  final String? registrationId;
  final int? userId;
  final bool captureOnly;

  bool get isOnboardingRegistration =>
      registrationId?.isNotEmpty == true && userId == null;

  bool get isRegistration => isOnboardingRegistration || userId != null;

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  late final AnimationController _scanController;

  String _title = 'Preparando a câmera';
  String _instruction = 'Mantenha o tablet na altura dos olhos.';
  double _progress = 0;
  bool _busy = true;
  bool _finished = false;
  bool _hasError = false;

  static const _panel = Color(0xFF171D23);
  static const _panelStrong = Color(0xFF11161C);
  static const _panelSoft = Color(0xFF202831);
  static const _line = Color(0xFF35404A);
  static const _accent = SteelColors.industrialAccent;
  static const _accentSoft = Color(0xFF6E5A32);

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat(reverse: true);
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
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camera!.initialize();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hasError = false;
        final strings = AppStrings.of(context);
        _title = widget.isRegistration
            ? strings.get('biometricRegister')
            : strings.get('faceRecognition');
        _instruction = strings.get('centerFace');
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted && !_busy && !_finished) await _start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hasError = true;
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
    setState(() {
      _busy = true;
      _hasError = false;
    });

    try {
      if (widget.isOnboardingRegistration) {
        await _onboardingRegistrationFlow();
      } else if (widget.userId != null) {
        await _existingUserRegistrationFlow();
      } else {
        await _loginFlow();
      }
    } on ApiException catch (exception) {
      _setError(exception.message);
    } catch (_) {
      _setError(strings.get('faceValidationFailed'));
    }
  }

  Future<void> _existingUserRegistrationFlow() async {
    final strings = AppStrings.of(context);
    _step(strings.get('lookCamera'), strings.get('keepFaceStill'), .35);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final image = await _capture();
    final analysis = await widget.controller.auth.analyzeFace(image);

    if (analysis['pronto'] != true) {
      throw ApiException(
        '${analysis['orientacao'] ?? strings.get('adjustPosition')}',
      );
    }

    _step(
      strings.get('qualityConfirmed'),
      strings.get('protectingBiometrics'),
      .78,
    );
    await widget.controller.companyApi.registerUserFace(widget.userId!, image);
    _success(
      strings.get('biometricsRegistered'),
      strings.get('biometricsLinkedOnce'),
      result: true,
    );
  }

  Future<void> _onboardingRegistrationFlow() async {
    final strings = AppStrings.of(context);

    _step(strings.get('firstPosition'), strings.get('lookCameraSentence'), .18);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    final first = await _capture();
    final firstAnalysis = await widget.controller.auth.analyzeFace(first);
    if (firstAnalysis['pronto'] != true) {
      throw ApiException(
        '${firstAnalysis['orientacao'] ?? strings.get('centerFace')}',
      );
    }

    _step(strings.get('liveness'), strings.get('turnHeadSlightly'), .46);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final liveness = await _capture();
    final motionAnalysis = await widget.controller.auth.analyzeFace(liveness);
    final yaw = _number((motionAnalysis['pose'] as Map?)?['yaw']);
    if (yaw.abs() < 10) {
      throw ApiException(strings.get('movementNotDetected'));
    }

    _step(strings.get('returnCenter'), strings.get('lookAgain'), .72);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    final finalImage = await _capture();
    final finalAnalysis = await widget.controller.auth.analyzeFace(finalImage);
    if (finalAnalysis['pronto'] != true) {
      throw ApiException(
        '${finalAnalysis['orientacao'] ?? strings.get('returnFront')}',
      );
    }

    _step(
      strings.get('verifyingIdentity'),
      strings.get('registrationCreatingAfterFace'),
      .90,
    );

    final session = await widget.controller.auth.completeRegistrationFace(
      verificationId: widget.registrationId!,
      finalImage: finalImage,
      livenessImage: liveness,
    );

    _success(
      strings.get('biometricsRegistered'),
      strings.get('registrationCompleteFace'),
      result: session,
    );
  }

  Future<void> _loginFlow() async {
    final strings = AppStrings.of(context);
    _step(strings.get('firstPosition'), strings.get('lookCameraSentence'), .18);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final first = await _capture();
    final firstAnalysis = await widget.controller.auth.analyzeFace(first);
    if (firstAnalysis['pronto'] != true) {
      throw ApiException(
        '${firstAnalysis['orientacao'] ?? strings.get('centerFace')}',
      );
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
      throw ApiException(
        '${finalAnalysis['orientacao'] ?? strings.get('returnFront')}',
      );
    }

    _step(
      strings.get('verifyingIdentity'),
      strings.get('confirmingAccess'),
      .90,
    );
    await widget.controller.loginWithFace(finalImage, liveness);
    _success(
      strings.get('identityConfirmed'),
      strings.get('welcomeEnvironment'),
      result: true,
    );
  }

  void _step(String title, String instruction, double progress) {
    if (!mounted) return;
    setState(() {
      _title = title;
      _instruction = instruction;
      _progress = progress;
      _hasError = false;
    });
  }

  void _success<T extends Object?>(
    String title,
    String instruction, {
    required T result,
  }) {
    if (!mounted) return;
    setState(() {
      _title = title;
      _instruction = instruction;
      _progress = 1;
      _busy = false;
      _finished = true;
      _hasError = false;
    });

    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      Navigator.pop<T>(context, result);
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _title = AppStrings.of(context).get('validationUnable');
      _instruction = widget.isOnboardingRegistration
          ? '$message ${AppStrings.of(context).get('registrationFaceRetry')}'
          : message;
      _progress = 0;
      _busy = false;
      _hasError = true;
    });
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  Color get _stateColor {
    if (_finished) return SteelColors.success;
    if (_hasError) return SteelColors.danger;
    return _accent;
  }

  IconData get _stateIcon {
    if (_finished) return Icons.verified_user_rounded;
    if (_hasError) return Icons.error_outline_rounded;
    if (_busy) return Icons.radar_rounded;
    return Icons.face_retouching_natural_rounded;
  }

  @override
  void dispose() {
    _scanController.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: _panelStrong,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tablet = constraints.maxWidth >= 760;
            final landscape = constraints.maxWidth > constraints.maxHeight;

            return Column(
              children: [
                _buildTopBar(strings, tablet),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      tablet ? 28 : 16,
                      tablet ? 18 : 10,
                      tablet ? 28 : 16,
                      tablet ? 26 : 20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: tablet && landscape
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: _buildCameraConsole(strings, true),
                                  ),
                                  const SizedBox(width: 22),
                                  SizedBox(
                                    width: 330,
                                    child: _buildStatusConsole(strings),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildCameraConsole(strings, false),
                                  const SizedBox(height: 18),
                                  _buildStatusConsole(strings),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(AppStrings strings, bool tablet) {
    return Container(
      height: tablet ? 82 : 70,
      padding: EdgeInsets.symmetric(horizontal: tablet ? 28 : 14),
      decoration: const BoxDecoration(
        color: Color(0xFF12181E),
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              backgroundColor: _panelSoft,
              foregroundColor: Colors.white,
              side: const BorderSide(color: _line),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          SizedBox(width: tablet ? 18 : 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
              color: _panelSoft,
            ),
            child: const Icon(
              Icons.face_retouching_natural_rounded,
              color: _accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isRegistration
                      ? strings.get('faceRegister')
                      : strings.get('faceIdTitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: tablet ? 19 : 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2,
                  ),
                ),
                if (tablet)
                  const Text(
                    'STEELCONTROL • BIOMETRIC SECURITY CORE',
                    style: TextStyle(
                      color: SteelColors.titanium,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.25,
                    ),
                  ),
              ],
            ),
          ),
          _StatusPill(
            color: _stateColor,
            icon: _stateIcon,
            label: _finished
                ? strings.get('protectedIdentity')
                : _busy
                    ? strings.get('automaticValidation')
                    : _hasError
                        ? strings.get('validationUnable')
                        : strings.get('positionFace'),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraConsole(AppStrings strings, bool tablet) {
    return Container(
      padding: EdgeInsets.all(tablet ? 18 : 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.translate(_title),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: tablet ? 24 : 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      strings.translate(_instruction),
                      style: TextStyle(
                        color: _hasError
                            ? const Color(0xFFF2A6A6)
                            : SteelColors.titaniumLight,
                        fontSize: tablet ? 13 : 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _stateColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _stateColor.withValues(alpha: .34),
                  ),
                ),
                child: Icon(_stateIcon, color: _stateColor),
              ),
            ],
          ),
          SizedBox(height: tablet ? 16 : 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B1015),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _stateColor.withValues(alpha: .52),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: AspectRatio(
              aspectRatio: tablet ? 16 / 10 : 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_camera?.value.isInitialized == true)
                      CameraPreview(_camera!)
                    else
                      Container(
                        color: const Color(0xFF111820),
                        child: Center(
                          child: Icon(
                            Icons.face_rounded,
                            size: tablet ? 120 : 88,
                            color: SteelColors.titanium.withValues(alpha: .35),
                          ),
                        ),
                      ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _TechFaceGuidePainter(
                          stateColor: _stateColor,
                          success: _finished,
                        ),
                      ),
                    ),
                    if (!_finished && !_hasError)
                      IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _scanController,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment(
                                0,
                                (_scanController.value * 1.45) - .72,
                              ),
                              child: child,
                            );
                          },
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 46),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  _accent.withValues(alpha: .88),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withValues(alpha: .30),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: _CameraInstructionBar(
                        icon: _stateIcon,
                        color: _stateColor,
                        text: strings.get(
                          _finished ? 'protectedIdentity' : 'positionFace',
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: _TechBadge(
                        icon: Icons.videocam_outlined,
                        label: 'CAM 01',
                        color: _camera?.value.isInitialized == true
                            ? SteelColors.success
                            : SteelColors.titanium,
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 14,
                      child: _TechBadge(
                        icon: Icons.shield_outlined,
                        label: widget.isRegistration ? 'ENROLL' : 'VERIFY',
                        color: _accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ProgressRail(
            progress: _progress,
            color: _stateColor,
            error: _hasError,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusConsole(AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: _accent, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  strings.get('automaticValidation'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildValidationStep(
            icon: Icons.center_focus_strong_rounded,
            title: strings.get('firstPosition'),
            subtitle: strings.get('centerFace'),
            threshold: .18,
          ),
          _buildValidationStep(
            icon: Icons.motion_photos_on_outlined,
            title: strings.get('liveness'),
            subtitle: strings.get('turnHeadSlightly'),
            threshold: .46,
          ),
          _buildValidationStep(
            icon: Icons.face_retouching_natural_rounded,
            title: strings.get('returnCenter'),
            subtitle: strings.get('lookAgain'),
            threshold: .72,
          ),
          _buildValidationStep(
            icon: Icons.verified_user_outlined,
            title: strings.get('verifyingIdentity'),
            subtitle: strings.get('protectingBiometrics'),
            threshold: .90,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF13191F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: SteelColors.titanium,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    strings.get('imagesAuthOnly'),
                    style: const TextStyle(
                      color: SteelColors.titaniumLight,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_hasError) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _start,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: const Color(0xFF11161C),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(strings.get('retry')),
            ),
          ] else if (_busy) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.get('automaticValidation'),
                    style: const TextStyle(
                      color: SteelColors.titaniumLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValidationStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required double threshold,
  }) {
    final complete = _finished || _progress >= threshold;
    final active = !_finished && !_hasError && _progress < threshold;
    final color = complete
        ? SteelColors.success
        : active
            ? _accent
            : SteelColors.titanium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: complete
              ? SteelColors.success.withValues(alpha: .07)
              : const Color(0xFF1B2229),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: complete
                ? SteelColors.success.withValues(alpha: .22)
                : _line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                complete ? Icons.check_rounded : icon,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SteelColors.titanium,
                      fontSize: 10.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechBadge extends StatelessWidget {
  const _TechBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xDD11161C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraInstructionBar extends StatelessWidget {
  const _CameraInstructionBar({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xE612171C),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF38434C)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRail extends StatelessWidget {
  const _ProgressRail({
    required this.progress,
    required this.color,
    required this.error,
  });

  final double progress;
  final Color color;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final value = error ? 0.04 : progress.clamp(0.02, 1.0).toDouble();
    return Column(
      children: [
        Row(
          children: [
            const Text(
              'BIOMETRIC PIPELINE',
              style: TextStyle(
                color: SteelColors.titanium,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: const Color(0xFF29323A),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _TechFaceGuidePainter extends CustomPainter {
  const _TechFaceGuidePainter({
    required this.stateColor,
    required this.success,
  });

  final Color stateColor;
  final bool success;

  @override
  void paint(Canvas canvas, Size size) {
    final guideWidth = size.width * (size.width > size.height ? .36 : .62);
    final guideHeight = size.height * .68;
    final guide = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .47),
      width: guideWidth,
      height: guideHeight,
    );

    final maskPaint = Paint()..color = const Color(0x8A0B1015);
    final oval = Path()..addOval(guide);
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addPath(oval, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, maskPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .055)
      ..strokeWidth = .7;
    const gridGap = 46.0;
    for (double x = 0; x < size.width; x += gridGap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridGap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final glow = Paint()
      ..color = stateColor.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(guide, glow);

    final outline = Paint()
      ..color = success ? SteelColors.success : stateColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(guide, outline);

    final centerLine = Paint()
      ..color = Colors.white.withValues(alpha: .11)
      ..strokeWidth = .8;
    canvas.drawLine(
      Offset(size.width / 2, guide.top + 18),
      Offset(size.width / 2, guide.bottom - 18),
      centerLine,
    );

    final corner = Paint()
      ..color = success ? SteelColors.success : const Color(0xFFE9EDF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const length = 26.0;
    const inset = 16.0;
    final corners = [
      Offset(guide.left - inset, guide.top - inset),
      Offset(guide.right + inset, guide.top - inset),
      Offset(guide.left - inset, guide.bottom + inset),
      Offset(guide.right + inset, guide.bottom + inset),
    ];

    for (final point in corners) {
      final sx = point.dx < size.width / 2 ? 1.0 : -1.0;
      final sy = point.dy < size.height / 2 ? 1.0 : -1.0;
      canvas.drawLine(point, point + Offset(sx * length, 0), corner);
      canvas.drawLine(point, point + Offset(0, sy * length), corner);
    }
  }

  @override
  bool shouldRepaint(_TechFaceGuidePainter oldDelegate) {
    return oldDelegate.success != success || oldDelegate.stateColor != stateColor;
  }
}

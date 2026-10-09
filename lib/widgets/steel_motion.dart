import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_theme.dart';

/// Transição curta usada entre os módulos principais do aplicativo.
/// Mantém a interface fluida sem atrasar comandos ou bloquear interações.
class SteelPageSwap extends StatelessWidget {
  const SteelPageSwap({required this.child, required this.transitionKey, super.key});

  final Widget child;
  final Object transitionKey;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      reverseDuration: reduceMotion ? Duration.zero : const Duration(milliseconds: 150),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (current, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(.018, .012),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: current),
        );
      },
      child: KeyedSubtree(key: ValueKey<Object>(transitionKey), child: child),
    );
  }
}

/// Montagem da marca exibida depois que a autenticação termina.
/// O corpo permanece fixo e o capacete industrial cai e encaixa sobre ele,
/// repetindo a mesma sequência visual usada pelo Desktop.
class SteelHardhatWelcome extends StatefulWidget {
  const SteelHardhatWelcome({super.key});

  @override
  State<SteelHardhatWelcome> createState() => _SteelHardhatWelcomeState();
}

class _SteelHardhatWelcomeState extends State<SteelHardhatWelcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fall;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    _fall = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .88, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark ? Colors.white : SteelColors.ink;

    return Semantics(
      label: 'Identidade industrial SteelControl validada',
      image: true,
      child: SizedBox(
        width: 118,
        height: 122,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final value = _fall.value;
            final impactPhase = ((_controller.value - .57) / .34)
                .clamp(0.0, 1.0)
                .toDouble();
            final impactOpacity = math
                .sin(impactPhase * math.pi)
                .clamp(0.0, 1.0)
                .toDouble();
            final bounce = math.sin(value * math.pi * 2) * (1 - value) * 4;

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  bottom: 3,
                  child: Opacity(
                    opacity: impactOpacity,
                    child: Transform.scale(
                      scale: .55 + impactPhase * .75,
                      child: Container(
                        width: 102,
                        height: 102,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: SteelColors.industrialAccent.withValues(alpha: .54),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 23,
                  bottom: 4,
                  width: 72,
                  height: 72,
                  child: SvgPicture.asset(
                    'assets/images/steel-mascot-body.svg',
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  ),
                ),
                Positioned(
                  left: 25,
                  top: 3,
                  width: 68,
                  height: 43,
                  child: Transform.translate(
                    offset: Offset(0, -112 * (1 - value) + 13 + bounce),
                    child: Transform.rotate(
                      angle: (-.24 * (1 - value)) + (math.sin(value * math.pi) * .05),
                      child: SvgPicture.asset(
                        'assets/images/steel-hardhat.svg',
                        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
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
}

/// Cena industrial leve inspirada na landing desktop. Ela usa apenas Canvas,
/// portanto funciona em tablets sem WebGL e não adiciona dependências ao app.
class SteelIndustrialMotion extends StatefulWidget {
  const SteelIndustrialMotion({this.compact = false, super.key});

  final bool compact;

  @override
  State<SteelIndustrialMotion> createState() => _SteelIndustrialMotionState();
}

class _SteelIndustrialMotionState extends State<SteelIndustrialMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final height = widget.compact ? 116.0 : 190.0;
    return Semantics(
      label: 'Rede industrial SteelControl conectando máquinas ao painel',
      image: true,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1014),
          border: Border.all(color: const Color(0xFF303A40)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x52000000), blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: reduceMotion
            ? const CustomPaint(painter: _IndustrialMotionPainter(.18))
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _IndustrialMotionPainter(_controller.value),
                ),
              ),
      ),
    );
  }
}

class _IndustrialMotionPainter extends CustomPainter {
  const _IndustrialMotionPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF6B7780).withValues(alpha: .10)
      ..strokeWidth = 1;
    final line = Paint()
      ..color = SteelColors.industrialAccent.withValues(alpha: .44)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final glow = Paint()
      ..color = SteelColors.industrialAccent.withValues(alpha: .12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    const spacing = 24.0;
    for (var x = -spacing; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + 38, size.height), grid);
    }
    for (var y = 10.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), grid);
    }

    final center = Offset(size.width * .5, size.height * .52);
    final nodes = <Offset>[
      Offset(size.width * .13, size.height * .30),
      Offset(size.width * .28, size.height * .72),
      Offset(size.width * .72, size.height * .27),
      Offset(size.width * .86, size.height * .70),
    ];

    for (final node in nodes) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          (center.dx + node.dx) / 2,
          center.dy + (node.dy < center.dy ? -18 : 18),
          node.dx,
          node.dy,
        );
      canvas.drawPath(path, line);
      final metric = path.computeMetrics().first;
      final phase = (progress + nodes.indexOf(node) * .19) % 1;
      final point = metric.getTangentForOffset(metric.length * phase)?.position;
      if (point != null) {
        canvas.drawCircle(point, 10, glow);
        canvas.drawCircle(point, 2.6, Paint()..color = const Color(0xFFFFB24A));
      }
      _machineNode(canvas, node, nodes.indexOf(node));
    }

    final pulse = 1 + math.sin(progress * math.pi * 2) * .06;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pulse);
    canvas.drawCircle(Offset.zero, 28, glow);
    canvas.drawCircle(
      Offset.zero,
      23,
      Paint()
        ..color = const Color(0xFF151D22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset.zero,
      23,
      Paint()
        ..color = SteelColors.industrialAccent
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    final iconData = Icons.hub_rounded;
    final icon = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          color: const Color(0xFFFFB24A),
          fontSize: 18,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, Offset(-icon.width / 2, -icon.height / 2));
    canvas.restore();

    final label = TextPainter(
      text: const TextSpan(
        text: 'EDGE  •  TELEMETRIA EM TEMPO REAL',
        style: TextStyle(
          color: Color(0xFF96A2AA),
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 24);
    label.paint(canvas, Offset(12, size.height - 18));
  }

  void _machineNode(Canvas canvas, Offset center, int index) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 38, height: 30),
      const Radius.circular(7),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF182126));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFF3A464D)
        ..style = PaintingStyle.stroke,
    );
    final glyphs = <IconData>[
      Icons.precision_manufacturing_rounded,
      Icons.sync_alt_rounded,
      Icons.view_in_ar_rounded,
      Icons.developer_board_rounded,
    ];
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(glyphs[index].codePoint),
        style: TextStyle(
          color: const Color(0xFFE7EBED),
          fontSize: 16,
          fontFamily: glyphs[index].fontFamily,
          package: glyphs[index].fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _IndustrialMotionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

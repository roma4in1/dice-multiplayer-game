import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'dice_widget.dart';

class RollingDiceWidget extends StatefulWidget {
  final double size;
  final Color? color;

  const RollingDiceWidget({super.key, this.size = 50, this.color});

  @override
  State<RollingDiceWidget> createState() => _RollingDiceWidgetState();
}

class _RollingDiceWidgetState extends State<RollingDiceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _rng = math.Random();
  int _face = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    )..repeat();

    _controller.addListener(() {
      if (mounted) setState(() => _face = _rng.nextInt(6) + 1);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wobble: oscillate ±8° using the animation value
    final angle = math.sin(_controller.value * math.pi * 2) * 0.14;

    return Transform.rotate(
      angle: angle,
      child: _StyledRollingFace(
        face: _face,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}

/// The visual face — separated so it can be const when color/size don't change.
class _StyledRollingFace extends StatelessWidget {
  final int face;
  final double size;
  final Color? color;

  const _StyledRollingFace({
    required this.face,
    required this.size,
    this.color,
  });

  bool get _isColored => color != null;

  LinearGradient get _gradient {
    if (_isColored) {
      final c = color!;
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(c, Colors.white, 0.18)!,
          c,
          Color.lerp(c, Colors.black, 0.22)!,
        ],
      );
    }
    return AppTheme.diceIvoryGradient;
  }

  Color get _pipColor => _isColored ? Colors.white : const Color(0xFF2D2520);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(size * 0.16),
        border: Border.all(
          color: _isColored
              ? Color.lerp(color!, Colors.black, 0.3)!
              : AppTheme.cardBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isColored ? color! : Colors.black)
                .withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(3, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 3,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top-left bevel highlight
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: size * 0.45,
              height: size * 0.22,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: _isColored ? 0.25 : 0.55),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size * 0.16),
                  bottomRight: const Radius.circular(6),
                ),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: size * 0.78,
              height: size * 0.78,
              child: CustomPaint(
                painter: _DicePipsPainter(face, _pipColor, size * 0.11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Duplicate of the painter in dice_widget — kept private to this file.
class _DicePipsPainter extends CustomPainter {
  final int value;
  final Color pipColor;
  final double pipRadius;

  _DicePipsPainter(this.value, this.pipColor, this.pipRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = pipColor..style = PaintingStyle.fill;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: pipColor == Colors.white ? 0.18 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final w = size.width;
    final h = size.height;

    final pos = {
      'c':  Offset(w / 2,    h / 2),
      'tl': Offset(w * 0.25, h * 0.25),
      'tr': Offset(w * 0.75, h * 0.25),
      'ml': Offset(w * 0.25, h / 2),
      'mr': Offset(w * 0.75, h / 2),
      'bl': Offset(w * 0.25, h * 0.75),
      'br': Offset(w * 0.75, h * 0.75),
    };

    void pip(String k) {
      canvas.drawCircle(pos[k]!.translate(0, 0.8), pipRadius, shadow);
      canvas.drawCircle(pos[k]!, pipRadius, paint);
    }

    switch (value) {
      case 1: pip('c');
      case 2: pip('tl'); pip('br');
      case 3: pip('tl'); pip('c'); pip('br');
      case 4: pip('tl'); pip('tr'); pip('bl'); pip('br');
      case 5: pip('tl'); pip('tr'); pip('c'); pip('bl'); pip('br');
      case 6: pip('tl'); pip('tr'); pip('ml'); pip('mr'); pip('bl'); pip('br');
    }
  }

  @override
  bool shouldRepaint(_DicePipsPainter old) =>
      old.value != value || old.pipColor != pipColor;
}

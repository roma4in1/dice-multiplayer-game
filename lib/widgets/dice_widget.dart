import 'dart:ui';
import 'package:flutter/material.dart';
import '../app_theme.dart';

class DiceWidget extends StatelessWidget {
  final int? value;
  final double size;
  final Color? color;
  final bool isSelected;
  final bool isUsed;
  final String? label;
  final VoidCallback? onTap;

  const DiceWidget({
    super.key,
    this.value,
    this.size = 50,
    this.color,
    this.isSelected = false,
    this.isUsed = false,
    this.label,
    this.onTap,
  });

  bool get _isColored => color != null;

  LinearGradient get _faceGradient {
    if (isUsed) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD8D5CF), Color(0xFFC8C5BF)],
      );
    }
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

  Color get _pipColor {
    if (isUsed) return const Color(0xFFAEA8A0);
    return _isColored ? Colors.white : const Color(0xFF2D2520);
  }

  Color get _borderColor {
    if (isUsed) return const Color(0xFFB8B4AC);
    if (isSelected) return AppTheme.gold;
    if (_isColored) return Color.lerp(color!, Colors.black, 0.3)!;
    return AppTheme.cardBorder;
  }

  List<BoxShadow> get _shadows {
    if (isUsed) return [];
    if (isSelected) {
      return [
        BoxShadow(
          color: AppTheme.gold.withValues(alpha: 0.55),
          blurRadius: 14,
          spreadRadius: 2,
        ),
        const BoxShadow(
          color: Color(0x44000000),
          blurRadius: 6,
          offset: Offset(2, 4),
        ),
      ];
    }
    return [
      // Bottom-right drop shadow
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.28),
        blurRadius: 6,
        offset: const Offset(2, 4),
      ),
      // Top-left highlight (light reflection)
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.75),
        blurRadius: 3,
        offset: const Offset(-1, -1),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    Widget face = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _faceGradient,
        borderRadius: BorderRadius.circular(size * 0.16),
        border: Border.all(color: _borderColor, width: isSelected ? 2.5 : 1.5),
        boxShadow: _shadows,
      ),
      child: Stack(
        children: [
          // Inner bevel highlight (top-left corner shimmer)
          if (!isUsed)
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
                    bottomRight: const Radius.circular(8),
                  ),
                ),
              ),
            ),

          // Pip dots or question mark
          Center(
            child: value == null
                ? Text(
                    '?',
                    style: TextStyle(
                      color: _pipColor,
                      fontSize: size * 0.44,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : _buildPips(value!),
          ),

          // Gold check badge when selected
          if (isSelected)
            Positioned(
              top: size * 0.04,
              right: size * 0.04,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: const BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: size * 0.2),
              ),
            ),

          // Subtle X overlay for used dice
          if (isUsed)
            Center(
              child: Icon(
                Icons.close_rounded,
                size: size * 0.45,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );

    // Bounce scale on selection / deselection
    face = AnimatedScale(
      scale: isSelected ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.elasticOut,
      child: face,
    );

    return GestureDetector(
      onTap: isUsed ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          face,
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: TextStyle(
                fontSize: size * 0.18,
                fontWeight: FontWeight.bold,
                color: _isColored ? color : const Color(0xFF5A5248),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPips(int value) {
    return SizedBox(
      width: size * 0.78,
      height: size * 0.78,
      child: CustomPaint(
        painter: _DicePipsPainter(value, _pipColor, size * 0.11),
      ),
    );
  }
}

class _DicePipsPainter extends CustomPainter {
  final int value;
  final Color pipColor;
  final double pipRadius;

  _DicePipsPainter(this.value, this.pipColor, this.pipRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = pipColor
      ..style = PaintingStyle.fill;

    // Subtle shadow under each pip for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: pipColor == Colors.white ? 0.18 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final w = size.width;
    final h = size.height;

    final positions = {
      'c':  Offset(w / 2,    h / 2),
      'tl': Offset(w * 0.25, h * 0.25),
      'tr': Offset(w * 0.75, h * 0.25),
      'ml': Offset(w * 0.25, h / 2),
      'mr': Offset(w * 0.75, h / 2),
      'bl': Offset(w * 0.25, h * 0.75),
      'br': Offset(w * 0.75, h * 0.75),
    };

    void drawPip(String key) {
      final pos = positions[key]!;
      canvas.drawCircle(pos.translate(0, 0.8), pipRadius, shadowPaint);
      canvas.drawCircle(pos, pipRadius, paint);
    }

    switch (value) {
      case 1:
        drawPip('c');
      case 2:
        drawPip('tl'); drawPip('br');
      case 3:
        drawPip('tl'); drawPip('c'); drawPip('br');
      case 4:
        drawPip('tl'); drawPip('tr'); drawPip('bl'); drawPip('br');
      case 5:
        drawPip('tl'); drawPip('tr'); drawPip('c'); drawPip('bl'); drawPip('br');
      case 6:
        drawPip('tl'); drawPip('tr'); drawPip('ml'); drawPip('mr'); drawPip('bl'); drawPip('br');
    }
  }

  @override
  bool shouldRepaint(_DicePipsPainter old) =>
      old.value != value || old.pipColor != pipColor;
}

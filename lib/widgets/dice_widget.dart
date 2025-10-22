import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isUsed ? Colors.grey[300] : color ?? Colors.white;

    final borderColor = isSelected
        ? Colors.green[700]!
        : isUsed
        ? Colors.grey[400]!
        : Colors.grey[400]!;

    final borderWidth = isSelected ? 4.0 : 2.0;

    return GestureDetector(
      onTap: isUsed ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: isUsed
                  ? []
                  : isSelected
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Center(
                  child: value == null
                      ? Text(
                          '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size * 0.5,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : _buildPips(value!),
                ),
                if (isSelected)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: size * 0.25,
                      height: size * 0.25,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: size * 0.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: TextStyle(
                fontSize: size * 0.18,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPips(int value) {
    final pipColor = isUsed ? Colors.grey[500]! : Colors.black87;
    final pipSize = size * 0.12;

    return SizedBox(
      width: size * 0.8,
      height: size * 0.8,
      child: CustomPaint(painter: DicePipsPainter(value, pipColor, pipSize)),
    );
  }
}

class DicePipsPainter extends CustomPainter {
  final int value;
  final Color pipColor;
  final double pipSize;

  DicePipsPainter(this.value, this.pipColor, this.pipSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = pipColor
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Pip positions (relative to size)
    final positions = {
      'center': Offset(w / 2, h / 2),
      'topLeft': Offset(w * 0.25, h * 0.25),
      'topRight': Offset(w * 0.75, h * 0.25),
      'middleLeft': Offset(w * 0.25, h / 2),
      'middleRight': Offset(w * 0.75, h / 2),
      'bottomLeft': Offset(w * 0.25, h * 0.75),
      'bottomRight': Offset(w * 0.75, h * 0.75),
    };

    void drawPip(Offset position) {
      canvas.drawCircle(position, pipSize, paint);
    }

    switch (value) {
      case 1:
        drawPip(positions['center']!);
        break;
      case 2:
        drawPip(positions['topLeft']!);
        drawPip(positions['bottomRight']!);
        break;
      case 3:
        drawPip(positions['topLeft']!);
        drawPip(positions['center']!);
        drawPip(positions['bottomRight']!);
        break;
      case 4:
        drawPip(positions['topLeft']!);
        drawPip(positions['topRight']!);
        drawPip(positions['bottomLeft']!);
        drawPip(positions['bottomRight']!);
        break;
      case 5:
        drawPip(positions['topLeft']!);
        drawPip(positions['topRight']!);
        drawPip(positions['center']!);
        drawPip(positions['bottomLeft']!);
        drawPip(positions['bottomRight']!);
        break;
      case 6:
        drawPip(positions['topLeft']!);
        drawPip(positions['topRight']!);
        drawPip(positions['middleLeft']!);
        drawPip(positions['middleRight']!);
        drawPip(positions['bottomLeft']!);
        drawPip(positions['bottomRight']!);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'dart:math';

class RollingDiceWidget extends StatefulWidget {
  final double size;
  final Color? color;

  const RollingDiceWidget({super.key, this.size = 50, this.color});

  @override
  State<RollingDiceWidget> createState() => _RollingDiceWidgetState();
}

class _RollingDiceWidgetState extends State<RollingDiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  int _currentValue = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..repeat();

    _controller.addListener(() {
      setState(() {
        _currentValue = _random.nextInt(6) + 1;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: _buildPips(_currentValue)),
    );
  }

  Widget _buildPips(int value) {
    final pipColor = Colors.black87;
    final pipSize = widget.size * 0.12;

    return SizedBox(
      width: widget.size * 0.8,
      height: widget.size * 0.8,
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

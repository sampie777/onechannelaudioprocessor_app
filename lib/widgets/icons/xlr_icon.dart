import 'package:flutter/material.dart';

class XlrIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const XlrIcon({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _XlrConnectorPainter(color: color ?? Colors.white70),
    );
  }
}

class _XlrConnectorPainter extends CustomPainter {
  final Color color;

  _XlrConnectorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, size.height / 2);

    // Outer Circle Shell
    final Paint outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius - 2, outerPaint);

    // Inner Notch (Top of XLR socket)
    final Paint notchPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Path notchPath = Path()
      ..addRect(Rect.fromLTWH(center.dx - 2.5, center.dy - radius + 2, 5, 4));
    canvas.drawPath(notchPath, notchPaint);

    // 3 Female Socket Pins
    final Paint pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final List<Offset> pinPositions = [
      Offset(center.dx - (radius * 0.42), center.dy - (radius * 0.15)),
      Offset(center.dx + (radius * 0.42), center.dy - (radius * 0.15)),
      Offset(center.dx, center.dy + (radius * 0.45)),
    ];

    for (final pos in pinPositions) {
      canvas.drawCircle(pos, 2.8, pinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _XlrConnectorPainter oldDelegate) =>
      oldDelegate.color != color;
}

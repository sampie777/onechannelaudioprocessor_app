import 'package:flutter/material.dart';

class JackIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const JackIcon({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _JackConnectorPainter(color: color ?? Colors.white70),
    );
  }
}

class _JackConnectorPainter extends CustomPainter {
  final Color color;

  _JackConnectorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double midY = size.height / 2;

    // 1. Heavy Base Handle / Sleeve
    canvas.drawRect(Rect.fromLTWH(1, midY - 9, 10, 18), fillPaint);

    // 2. Main Shaft
    canvas.drawRect(Rect.fromLTWH(10, midY - 5.5, 22, 11), strokePaint);

    // 3. TRS Insulator Ring Line
    canvas.drawLine(
      Offset(24, midY - 5.5),
      Offset(24, midY + 5.5),
      strokePaint,
    );

    // 4. Jack Tip (Notched Arrow Point)
    final double offsetX = 32;
    final Path tipPath = Path()
      ..moveTo(offsetX, midY - 5.5)
      ..lineTo(offsetX + 4, midY - 4.0)
      ..lineTo(offsetX + 10, midY - 2.0)
      ..lineTo(offsetX + 10, midY + 2.0)
      ..lineTo(offsetX + 4, midY + 4.0)
      ..lineTo(offsetX, midY + 5.5)
      ..close();

    canvas.drawPath(tipPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _JackConnectorPainter oldDelegate) =>
      oldDelegate.color != color;
}

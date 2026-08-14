import 'package:flutter/material.dart';

class GroundIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool isLifted;

  const GroundIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.isLifted = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GroundSymbolPainter(
        isLifted: isLifted,
        color: color ?? (isLifted ? Colors.amber : Colors.white70),
      ),
    );
  }
}

class _GroundSymbolPainter extends CustomPainter {
  final bool isLifted;
  final Color color;

  _GroundSymbolPainter({required this.isLifted, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final double midX = size.width / 2;

    if (isLifted) {
      // 1. Lifted: Draw top wire down to gap
      canvas.drawLine(Offset(midX, 0), Offset(midX, 6), linePaint);

      // 2. Break / Disconnect gap (red/amber 'X' cut indicator)
      final Paint cutPaint = Paint()
        ..color = Colors.amber
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(midX - 3, 7), Offset(midX + 3, 11), cutPaint);
      canvas.drawLine(Offset(midX + 3, 7), Offset(midX - 3, 11), cutPaint);

      // 3. Lower stem starting below the break gap
      canvas.drawLine(Offset(midX, 12), Offset(midX, 16), linePaint);
    } else {
      // Intact continuous wire from top stem to earth lines
      canvas.drawLine(Offset(midX, 0), Offset(midX, 16), linePaint);
    }

    // 4. Standard 3-line Earth Ground Schematic pyramid (Bottom)
    // Top line (widest)
    canvas.drawLine(Offset(midX - 10, 16), Offset(midX + 10, 16), linePaint);
    // Middle line
    canvas.drawLine(Offset(midX - 6, 20), Offset(midX + 6, 20), linePaint);
    // Bottom line (narrowest)
    canvas.drawLine(Offset(midX - 2, 24), Offset(midX + 2, 24), linePaint);
  }

  @override
  bool shouldRepaint(covariant _GroundSymbolPainter oldDelegate) =>
      oldDelegate.isLifted != isLifted;
}

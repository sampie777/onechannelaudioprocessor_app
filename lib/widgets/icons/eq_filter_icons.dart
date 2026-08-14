import 'package:flutter/material.dart';

enum EqFilterType {
  highPass,
  lowPass,
  bandPass,
  lowShelf,
  highShelf,
}

/// A versatile EQ Filter Icon that renders realistic frequency response curves.
class EqFilterIcon extends StatelessWidget {
  final EqFilterType type;
  final double size;
  final Color? color;
  final double strokeWidth;
  final bool showZeroAxis;

  const EqFilterIcon({
    super.key,
    required this.type,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
    this.showZeroAxis = true,
  });

  const EqFilterIcon.highPass({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
    this.showZeroAxis = true,
  }) : type = EqFilterType.highPass;

  const EqFilterIcon.lowPass({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
    this.showZeroAxis = true,
  }) : type = EqFilterType.lowPass;

  const EqFilterIcon.bandPass({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
    this.showZeroAxis = true,
  }) : type = EqFilterType.bandPass;

  const EqFilterIcon.lowShelf({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
    this.showZeroAxis = true,
  }) : type = EqFilterType.lowShelf;

  const EqFilterIcon.highShelf({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
    this.showZeroAxis = true,
  }) : type = EqFilterType.highShelf;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.cyanAccent;

    return CustomPaint(
      size: Size(size, size),
      painter: _EqFilterPainter(
        type: type,
        color: iconColor,
        strokeWidth: strokeWidth,
        showZeroAxis: showZeroAxis,
      ),
    );
  }
}

class _EqFilterPainter extends CustomPainter {
  final EqFilterType type;
  final Color color;
  final double strokeWidth;
  final bool showZeroAxis;

  _EqFilterPainter({
    required this.type,
    required this.color,
    required this.strokeWidth,
    required this.showZeroAxis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Define consistent vertical baseline levels
    final double midY = h * 0.50; // 0 dB line
    final double highY = h * 0.20; // +Gain boost / Passband
    final double lowY = h * 0.82; // -Gain cut / Attenuation floor

    // 1. Draw subtle 0 dB reference line (axis)
    if (showZeroAxis) {
      final Paint axisPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(0, midY), Offset(w, midY), axisPaint);
    }

    final Path path = Path();

    // 2. Draw standard frequency response shapes using cubic beziers
    switch (type) {
      case EqFilterType.highPass:
      // Attenuates low frequencies, smoothly climbs up to the 0 dB passband
        path.moveTo(0, lowY);
        path.cubicTo(0, lowY, w * 0.35, midY, w * 0.50, midY);
        path.lineTo(w, midY);
        break;

      case EqFilterType.lowPass:
      // Passes low frequencies at 0 dB, rolls off sharply on high frequencies
        path.moveTo(0, midY);
        path.lineTo(w * 0.35, midY);
        path.cubicTo(w * 0.60, midY, w * 0.65, midY, w, lowY);
        break;

      case EqFilterType.bandPass:
      // Bell / Parametric curve peaking at the center
        path.moveTo(0, midY);
        path.lineTo(w * 0.20, midY);
        path.cubicTo(w * 0.35, midY, w * 0.38, highY, w * 0.50, highY);
        path.cubicTo(w * 0.62, highY, w * 0.65, midY, w * 0.80, midY);
        path.lineTo(w, midY);
        break;

      case EqFilterType.lowShelf:
      // Boosted low-end shelf transitioning down to 0 dB
        path.moveTo(0, highY);
        path.lineTo(w * 0.25, highY);
        path.cubicTo(w * 0.45, highY, w * 0.55, midY, w * 0.75, midY);
        path.lineTo(w, midY);
        break;

      case EqFilterType.highShelf:
      // 0 dB low-end transitioning up into a high-end boosted shelf
        path.moveTo(0, midY);
        path.lineTo(w * 0.25, midY);
        path.cubicTo(w * 0.45, midY, w * 0.55, highY, w * 0.75, highY);
        path.lineTo(w, highY);
        break;
    }

    final Paint curvePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(covariant _EqFilterPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showZeroAxis != showZeroAxis;
  }
}
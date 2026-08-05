import 'package:flutter/material.dart';

/// Converts a real dB value to a linear 0.0 - 1.0 slider fraction
double dbToLinear(List<double> faderStops, double db) {
  if (db <= faderStops.first) return 0.0;
  if (db >= faderStops.last) return 1.0;

  for (int i = 0; i < faderStops.length - 1; i++) {
    if (db >= faderStops[i] && db <= faderStops[i + 1]) {
      double range = faderStops[i + 1] - faderStops[i];
      double fraction = (db - faderStops[i]) / range;
      // Each segment represents an equal 1/6th portion of the physical slider
      return (i + fraction) / (faderStops.length - 1);
    }
  }
  return 0.0;
}

/// Converts a 0.0 - 1.0 slider fraction back to a real dB value
double linearToDb(List<double> faderStops, double linear) {
  if (linear <= 0.0) return faderStops.first;
  if (linear >= 1.0) return faderStops.last;

  double scaled = linear * (faderStops.length - 1);
  int index = scaled.floor();
  double fraction = scaled - index;

  if (index >= faderStops.length - 1) return faderStops.last;

  return faderStops[index] + fraction * (faderStops[index + 1] - faderStops[index]);
}

class FaderScalePainter extends CustomPainter {
  final List<double> faderStops;
  final List<double> ticks;

  // Must match the overlayRadius of the SliderTheme
  final double sliderPadding = 25.0;
  final double topOffset = 0.0;

  FaderScalePainter({
    required this.faderStops,
    required this.ticks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double trackLength = size.height - (sliderPadding * 2);
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final tick in ticks) {
      // Use piecewise interpolation instead of linear fraction
      final fraction = dbToLinear(faderStops, tick);

      final y =
          size.height - sliderPadding - (fraction * trackLength) + topOffset;

      final isUnity = tick == 0.0;
      final lineLength = isUnity ? 12.0 : 8.0;

      paint.color = isUnity ? Colors.cyan : Colors.grey.shade600;
      paint.strokeWidth = isUnity ? 2.5 : 2.0;
      canvas.drawLine(Offset(0, y), Offset(lineLength, y), paint);

      final text = tick > 0 ? '+${tick.toInt()}' : tick.toInt().toString();
      final textStyle = TextStyle(
        color: isUnity ? Colors.cyan : Colors.grey.shade500,
        fontSize: 12,
        fontWeight: isUnity ? FontWeight.w900 : FontWeight.bold,
      );

      final tp = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      tp.paint(canvas, Offset(16, y - (tp.height / 2)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FaderThumbShape extends SliderComponentShape {
  final double faderWidth;
  final double faderLength;

  const FaderThumbShape({this.faderWidth = 32.0, this.faderLength = 80.0});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(faderWidth, faderLength);
  }

  @override
  void paint(
      PaintingContext context,
      Offset center, {
        required Animation<double> activationAnimation,
        required Animation<double> enableAnimation,
        required bool isDiscrete,
        required TextPainter labelPainter,
        required RenderBox parentBox,
        required SliderThemeData sliderTheme,
        required TextDirection textDirection,
        required double value,
        required double textScaleFactor,
        required Size sizeWithOverflow,
      }) {
    final Canvas canvas = context.canvas;

    final RRect thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: faderWidth, height: faderLength),
      const Radius.circular(6.0),
    );

    canvas.drawShadow(Path()..addRRect(thumbRect), Colors.black, 4.0, true);

    final Paint thumbPaint = Paint()..color = Colors.grey.shade300;
    canvas.drawRRect(thumbRect, thumbPaint);

    final Paint linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx, center.dy - (faderLength / 2) + 12),
      Offset(center.dx, center.dy + (faderLength / 2) - 12),
      linePaint,
    );
  }
}
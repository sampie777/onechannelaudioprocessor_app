import 'package:flutter/material.dart';

class FaderScalePainter extends CustomPainter {
  final double min;
  final double max;
  final List<double> ticks;

  // Must match the overlayRadius of the SliderTheme
  final double sliderPadding = 30.0;

  // ⬇️ ADJUST THIS OFFSET TO SHIFT THE SCALE UP/DOWN ⬇️
  final double topOffset = 0.0;

  FaderScalePainter({
    required this.min,
    required this.max,
    required this.ticks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double trackLength = size.height - (sliderPadding * 2);
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final tick in ticks) {
      final fraction = (tick - min) / (max - min);

      // Added the topOffset here so the whole scale shifts down
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

    // Define the rectangle for the fader.
    // Because the slider is inside a RotatedBox(-90deg), the local width (X)
    // translates to the screen's vertical axis, and local height (Y) translates to horizontal.
    final RRect thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: faderWidth, height: faderLength),
      const Radius.circular(6.0), // Slightly rounded corners
    );

    // 1. Draw a drop shadow to lift it off the track
    canvas.drawShadow(Path()..addRRect(thumbRect), Colors.black, 4.0, true);

    // 2. Draw the main fader body (Light grey like a mixing console)
    final Paint thumbPaint = Paint()..color = Colors.grey.shade300;
    canvas.drawRRect(thumbRect, thumbPaint);

    // 3. Draw the center "grip" line
    final Paint linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // We draw the line along the local Y axis (which renders horizontally on the screen)
    canvas.drawLine(
      Offset(center.dx, center.dy - (faderLength / 2) + 12),
      // Start slightly inside the edge
      Offset(center.dx, center.dy + (faderLength / 2) - 12),
      // End slightly inside the edge
      linePaint,
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

/// Single sine wave representing an Unbalanced Audio Signal (Hot + Ground)
class UnbalancedSignalIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const UnbalancedSignalIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.white;

    return CustomPaint(
      size: Size(size, size),
      painter: _SignalWavePainter(
        isBalanced: false,
        primaryColor: iconColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

/// Dual, opposite-phase sine waves (180° out of phase) representing
/// a Balanced Audio Signal (Hot + Cold + Ground)
class BalancedSignalIcon extends StatelessWidget {
  final double size;
  final Color? primaryColor;
  final Color? invertedColor;
  final double strokeWidth;

  const BalancedSignalIcon({
    super.key,
    this.size = 24.0,
    this.primaryColor,
    this.invertedColor,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = primaryColor ?? IconTheme.of(context).color ?? Colors.cyanAccent;
    // Default inverted wave to a slightly dimmer/translucent shade for visual contrast
    final secondColor = invertedColor ?? baseColor.withValues(alpha: 0.55);

    return CustomPaint(
      size: Size(size, size),
      painter: _SignalWavePainter(
        isBalanced: true,
        primaryColor: baseColor,
        invertedColor: secondColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _SignalWavePainter extends CustomPainter {
  final bool isBalanced;
  final Color primaryColor;
  final Color? invertedColor;
  final double strokeWidth;

  _SignalWavePainter({
    required this.isBalanced,
    required this.primaryColor,
    this.invertedColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2.0;
    final double amplitude = size.height * 0.36; // Wave height boundary
    const int resolution = 40;

    final Path normalPath = Path();
    final Path invertedPath = Path();

    for (int i = 0; i <= resolution; i++) {
      final double fraction = i / resolution;
      final double x = fraction * size.width;
      // Complete 1 full sine period across the width
      final double angle = fraction * 2 * pi;

      final double yNormal = midY - (sin(angle) * amplitude);
      final double yInverted = midY + (sin(angle) * amplitude); // 180° inverted

      if (i == 0) {
        normalPath.moveTo(x, yNormal);
        if (isBalanced) invertedPath.moveTo(x, yInverted);
      } else {
        normalPath.lineTo(x, yNormal);
        if (isBalanced) invertedPath.lineTo(x, yInverted);
      }
    }

    // 1. Draw the inverted (Cold) wave first if balanced
    if (isBalanced && invertedColor != null) {
      final Paint invPaint = Paint()
        ..color = invertedColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(invertedPath, invPaint);
    }

    // 2. Draw the primary (Hot) wave on top
    final Paint normalPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(normalPath, normalPaint);
  }

  @override
  bool shouldRepaint(covariant _SignalWavePainter oldDelegate) {
    return oldDelegate.isBalanced != isBalanced ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.invertedColor != invertedColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
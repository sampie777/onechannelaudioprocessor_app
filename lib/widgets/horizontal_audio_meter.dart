import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'audio_meter.dart';

class HorizontalAudioMeterWidget extends StatefulWidget {
  final double peak; // 0.0 - 1.0
  final double height;
  final bool showTicks;
  final String? label;

  const HorizontalAudioMeterWidget({
    super.key,
    required this.peak,
    this.height = 14.0,
    this.showTicks = false,
    this.label,
  });

  @override
  State<HorizontalAudioMeterWidget> createState() =>
      _HorizontalAudioMeterWidgetState();
}

class _HorizontalAudioMeterWidgetState
    extends State<HorizontalAudioMeterWidget>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _fallingPeak = 0.0;

  final List<double> _meterStops = [-60.0, -40.0, -20.0, -10.0, -5.0, 0.0];
  static const double _decayRatePerSecond = 0.05;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant HorizontalAudioMeterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.peak > _fallingPeak) {
      _fallingPeak = widget.peak.clamp(0.0, 1.0);
    }
  }

  void _onTick(Duration elapsed) {
    if (_fallingPeak <= 0.0) return;

    setState(() {
      _fallingPeak -= _decayRatePerSecond * (1 / 60.0);

      if (_fallingPeak < widget.peak) {
        _fallingPeak = widget.peak.clamp(0.0, 1.0);
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(fontSize: 12.0, color: Colors.grey),
          ),
          const SizedBox(height: 4),
        ],
        Container(
          height: widget.height,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: CustomPaint(
            size: Size.infinite,
            painter: _HorizontalMeterPainter(
              peakLinear: _fallingPeak,
              avgPeakLinear: widget.peak,
              meterStops: _meterStops,
            ),
          ),
        ),
        if (widget.showTicks) ...[
          const SizedBox(height: 2),
          SizedBox(
            height: 6,
            child: CustomPaint(
              size: Size.infinite,
              painter: _HorizontalMeterTicksPainter(meterStops: _meterStops),
            ),
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// HORIZONTAL METER PAINTER
// -----------------------------------------------------------------------------
class _HorizontalMeterPainter extends CustomPainter {
  final double peakLinear;
  final double avgPeakLinear;
  final List<double> meterStops;

  _HorizontalMeterPainter({
    required this.peakLinear,
    required this.avgPeakLinear,
    required this.meterStops,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double height = size.height;
    final double width = size.width;

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [Colors.green, Colors.yellow, Colors.red],
        stops: const [0.6, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    // Calculate bar width based on visual mapping
    final avgWidth =
        width * rawToVisualLinear(meterStops, avgPeakLinear).clamp(0.0, 1.0);
    final Rect barRect = Rect.fromLTWH(0, 0, avgWidth, height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
      fillPaint,
    );

    // Draw Peak Indicator Line
    if (peakLinear > 0.001) {
      final peakX =
          width * rawToVisualLinear(meterStops, peakLinear).clamp(0.0, 1.0);
      final Paint linePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(peakX, 1), Offset(peakX, height - 1), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalMeterPainter oldDelegate) {
    return oldDelegate.peakLinear != peakLinear ||
        oldDelegate.avgPeakLinear != avgPeakLinear;
  }
}

// -----------------------------------------------------------------------------
// HORIZONTAL TICK MARKS PAINTER
// -----------------------------------------------------------------------------
class _HorizontalMeterTicksPainter extends CustomPainter {
  final List<double> ticks = [0.0, -5.0, -10.0, -20.0, -40.0, -60.0];
  final List<double> meterStops;

  _HorizontalMeterTicksPainter({required this.meterStops});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final tick in ticks) {
      final double visualFraction = dbToVisualLinear(meterStops, tick);
      final double x = visualFraction * size.width;

      final isZero = tick == 0.0;
      paint.color = isZero ? Colors.redAccent : Colors.grey.shade600;
      paint.strokeWidth = isZero ? 2.0 : 1.0;

      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
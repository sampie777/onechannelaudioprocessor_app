import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/mixer_state.dart';
import '../../services/esp32_connection_service.dart';

// Shared Coordinate Constants
const double _minFreq = 18.0;
const double _maxFreq = 22000.0;
const double _maxDb = 15.0;
const double _minDb = -15.0;

// -----------------------------------------------------------------------------
// SHARED EQ CONFIGURATION
// -----------------------------------------------------------------------------
class EqBandsConfig {
  static const List<int> highPassFreqs = [4, 122, 153, 156, 245, 306, 392, 490, 612];
  static const List<int> lowShelfFreqs = [80, 105, 135, 175];
  static const List<int> lowFreqs = [230, 300, 385, 500];
  static const List<int> midFreqs = [650, 850, 1100, 1400];
  static const List<int> highFreqs = [1800, 2400, 3200, 4100];
  static const List<int> highShelfFreqs = [5300, 6900, 9000, 11700];

  static int findClosestIndex(int target, List<int> array) {
    if (array.isEmpty) return 0;
    int closestIndex = 0;
    int minDiff = (array[0] - target).abs();
    for (int i = 1; i < array.length; i++) {
      int diff = (array[i] - target).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }
    return closestIndex;
  }
}

// -----------------------------------------------------------------------------
// INTERACTIVE GRAPH WIDGET
// -----------------------------------------------------------------------------
class InteractiveEqGraph extends StatefulWidget {
  final EqState eq;
  final List<double> spectrum;
  final String? activeBandKey;
  final Esp32ConnectionService service;
  final ValueChanged<String> onBandSelected;
  final VoidCallback onLocalStateChanged;

  const InteractiveEqGraph({
    super.key,
    required this.eq,
    required this.spectrum,
    required this.activeBandKey,
    required this.service,
    required this.onBandSelected,
    required this.onLocalStateChanged,
  });

  @override
  State<InteractiveEqGraph> createState() => _InteractiveEqGraphState();
}

class _InteractiveEqGraphState extends State<InteractiveEqGraph> {
  /// Internally locks onto the band being dragged the instant onPanDown fires.
  /// This prevents the "teleporting/resetting band" bug caused by state rebuild delays.
  String? _dragBandKey;

  String? get _effectiveBandKey => _dragBandKey ?? widget.activeBandKey;

  double _freqToX(double f, double width) =>
      width * (log(f / _minFreq) / log(_maxFreq / _minFreq));

  double _xToFreq(double x, double width) =>
      _minFreq * pow(_maxFreq / _minFreq, x / width);

  double _dbToY(double db, double height) {
    final double clampedDb = db.clamp(_minDb, _maxDb);
    final double normalized = 1.0 - ((clampedDb - _minDb) / (_maxDb - _minDb));
    return normalized * height;
  }

  double _yToDb(double y, double height) {
    final double normalized = 1.0 - (y / height);
    return (_minDb + normalized * (_maxDb - _minDb)).clamp(-12.0, 12.0);
  }

  void _handleGraphInteractionStart(Offset touch, Size size) {
    final Map<String, Offset> bandPositions = {
      'high_pass': Offset(
          _freqToX(widget.eq.highPass.frequency.value.toDouble(), size.width),
          _dbToY(0, size.height)),
      'low_shelf': Offset(
          _freqToX(widget.eq.lowShelf.frequency.value.toDouble(), size.width),
          _dbToY(widget.eq.lowShelf.uiGain.toDouble(), size.height)),
      'low': Offset(
          _freqToX(widget.eq.low.frequency.value.toDouble(), size.width),
          _dbToY(widget.eq.low.uiGain.toDouble(), size.height)),
      'mid': Offset(
          _freqToX(widget.eq.mid.frequency.value.toDouble(), size.width),
          _dbToY(widget.eq.mid.uiGain.toDouble(), size.height)),
      'high': Offset(
          _freqToX(widget.eq.high.frequency.value.toDouble(), size.width),
          _dbToY(widget.eq.high.uiGain.toDouble(), size.height)),
      'high_shelf': Offset(
          _freqToX(widget.eq.highShelf.frequency.value.toDouble(), size.width),
          _dbToY(widget.eq.highShelf.uiGain.toDouble(), size.height)),
    };

    String closest = 'high_pass';
    double minDist = double.infinity;

    for (var entry in bandPositions.entries) {
      final double dist = (entry.value - touch).distance;
      if (dist < minDist) {
        minDist = dist;
        closest = entry.key;
      }
    }

    // Instantly lock the local state to the closest band
    setState(() {
      _dragBandKey = closest;
    });

    // Notify parent to highlight the corresponding card below
    widget.onBandSelected(closest);
  }

  void _handleGraphPanUpdate(Offset touch, Size size) {
    // ALWAYS use the locally locked drag key to ensure we don't apply data to the wrong band
    final String? bandKey = _dragBandKey;
    if (bandKey == null) return;

    final double rawFreq = _xToFreq(touch.dx, size.width);
    final double rawDb = _yToDb(touch.dy, size.height);

    List<int> allowedFreqs;
    dynamic filter;
    bool isGainAllowed = true;

    switch (bandKey) {
      case 'high_pass':
        allowedFreqs = EqBandsConfig.highPassFreqs;
        filter = widget.eq.highPass;
        isGainAllowed = false;
        break;
      case 'low_shelf':
        allowedFreqs = EqBandsConfig.lowShelfFreqs;
        filter = widget.eq.lowShelf;
        break;
      case 'low':
        allowedFreqs = EqBandsConfig.lowFreqs;
        filter = widget.eq.low;
        break;
      case 'mid':
        allowedFreqs = EqBandsConfig.midFreqs;
        filter = widget.eq.mid;
        break;
      case 'high':
        allowedFreqs = EqBandsConfig.highFreqs;
        filter = widget.eq.high;
        break;
      case 'high_shelf':
        allowedFreqs = EqBandsConfig.highShelfFreqs;
        filter = widget.eq.highShelf;
        break;
      default:
        return;
    }

    final int closestFreq = allowedFreqs[EqBandsConfig.findClosestIndex(rawFreq.toInt(), allowedFreqs)];
    final int clampedDb = rawDb.round();

    final Map<String, String> cmds = {};
    bool freqChanged = false;

    if (filter.frequency.value != closestFreq) {
      cmds[filter.frequency.command] = closestFreq.toString();
      freqChanged = true;
    }

    if (isGainAllowed) {
      if (filter.isBypassed) {
        // Safe local state UI update when band is disabled
        if (filter.storedGain != clampedDb) {
          filter.storedGain = clampedDb;
          widget.onLocalStateChanged();
        }
      } else {
        // Send command update when band is active
        if (filter.gain.value != clampedDb) {
          cmds[filter.gain.command] = clampedDb.toString();
        }
      }
    }

    if (cmds.isNotEmpty) {
      widget.service.sendCommands(cmds);
    }

    if (freqChanged) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleGraphInteractionEnd() {
    setState(() {
      _dragBandKey = null; // Release the lock
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanDown: (details) => _handleGraphInteractionStart(details.localPosition, size),
          onPanUpdate: (details) => _handleGraphPanUpdate(details.localPosition, size),
          onPanEnd: (details) => _handleGraphInteractionEnd(),
          onPanCancel: () => _handleGraphInteractionEnd(),
          child: CustomPaint(
            size: size,
            painter: EqCurvePainter(
              eqState: widget.eq,
              spectrum: widget.spectrum,
              activeBandKey: _effectiveBandKey,
              freqToX: _freqToX,
              dbToY: _dbToY,
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// VISUAL EQ GRAPH PAINTER
// -----------------------------------------------------------------------------
class EqCurvePainter extends CustomPainter {
  final EqState eqState;
  final List<double> spectrum;
  final String? activeBandKey;

  final double Function(double, double) freqToX;
  final double Function(double, double) dbToY;

  EqCurvePainter({
    required this.eqState,
    required this.spectrum,
    required this.activeBandKey,
    required this.freqToX,
    required this.dbToY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black87;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      bgPaint,
    );

    _drawGridAndLabels(canvas, size);

    // -------------------------------------------------------------------------
    // FREQUENCY SPECTRUM BACKGROUND (SMOOTH LINE GRAPH)
    // -------------------------------------------------------------------------
    const double minSpectrumDb = -80.0;
    const double maxSpectrumDb = 0.0;

    final List<Offset> points = [];

    // Calculate all the exact coordinate points for the 32 bands
    for (int i = 0; i < 32; i++) {
      final double db = spectrum[i];
      final double clampedDb = db.clamp(minSpectrumDb, maxSpectrumDb);

      final double fStart = 20.0 * pow(10, (i * 3.0) / 32.0);
      final double fEnd = 20.0 * pow(10, ((i + 1) * 3.0) / 32.0);

      final double xStart = freqToX(fStart, size.width);
      final double xEnd = freqToX(fEnd, size.width);
      final double xCenter = (xStart + xEnd) / 2.0;

      final double normalizedDb = ((clampedDb - minSpectrumDb) / (maxSpectrumDb - minSpectrumDb));
      final double y = size.height - (size.height * normalizedDb);

      points.add(Offset(xCenter, y));
    }

    final Path spectrumPath = Path();

    if (points.isNotEmpty) {
      // Add ghost points to the edges to ensure the curve anchors smoothly to the sides
      final List<Offset> extendedPoints = [
        Offset(0, points.first.dy),
        ...points,
        Offset(size.width, points.last.dy)
      ];

      // Start the path at the far left edge
      spectrumPath.moveTo(extendedPoints[0].dx, extendedPoints[0].dy);

      // Loop through points and draw quadratic bezier curves connecting their midpoints
      for (int i = 0; i < extendedPoints.length - 1; i++) {
        final Offset current = extendedPoints[i];
        final Offset next = extendedPoints[i + 1];

        final double midX = (current.dx + next.dx) / 2.0;
        final double midY = (current.dy + next.dy) / 2.0;

        // Use the actual point as the anchor/control point, and draw to the midpoint
        spectrumPath.quadraticBezierTo(current.dx, current.dy, midX, midY);
      }

      // Complete the line to the far right boundary
      spectrumPath.lineTo(size.width, extendedPoints.last.dy);
    }

    // Draw the light grey, smooth spectrum line
    final Paint spectrumLinePaint = Paint()
      ..color = Colors.grey.shade300.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(spectrumPath, spectrumLinePaint);

    // Draw a soft grey gradient fill underneath the spectrum line for depth
    final Path spectrumFillPath = Path.from(spectrumPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final Paint spectrumFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.shade300.withOpacity(0.15),
          Colors.grey.shade300.withOpacity(0.0),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(spectrumFillPath, spectrumFillPaint);

    // -------------------------------------------------------------------------
    // EQ CURVE GENERATION
    // -------------------------------------------------------------------------
    final Path activePath = Path();
    final Path previewPath = Path();
    final int resolution = size.width.toInt();

    bool isFirst = true;

    for (int i = 0; i <= resolution; i++) {
      final double x = i.toDouble();
      final double freq = _minFreq * pow(_maxFreq / _minFreq, x / size.width);

      double activeGain = 0;
      activeGain += _calcHighPassGain(freq);
      activeGain += _calcShelfGain(freq, eqState.lowShelf, true);
      activeGain += _calcShelfGain(freq, eqState.highShelf, false);
      activeGain += _calcParametricGain(freq, eqState.low);
      activeGain += _calcParametricGain(freq, eqState.mid);
      activeGain += _calcParametricGain(freq, eqState.high);

      double previewGain = 0;
      previewGain += _calcHighPassGain(freq, forceActive: true);
      previewGain += _calcShelfGain(freq, eqState.lowShelf, true, useUiGain: true);
      previewGain += _calcShelfGain(freq, eqState.highShelf, false, useUiGain: true);
      previewGain += _calcParametricGain(freq, eqState.low, useUiGain: true);
      previewGain += _calcParametricGain(freq, eqState.mid, useUiGain: true);
      previewGain += _calcParametricGain(freq, eqState.high, useUiGain: true);

      final double yActive = dbToY(activeGain, size.height);
      final double yPreview = dbToY(previewGain, size.height);

      if (isFirst) {
        activePath.moveTo(x, yActive);
        previewPath.moveTo(x, yPreview);
        isFirst = false;
      } else {
        activePath.lineTo(x, yActive);
        previewPath.lineTo(x, yPreview);
      }
    }

    // Draw lines over the top of the spectrum
    final previewLinePaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(previewPath, previewLinePaint);

    final previewFillPath = Path.from(previewPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final previewFillPaint = Paint()..color = Colors.white10;
    canvas.drawPath(previewFillPath, previewFillPaint);

    final linePaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(activePath, linePaint);

    final fillPath = Path.from(activePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.cyanAccent.withOpacity(0.4),
          Colors.cyanAccent.withOpacity(0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    // Draw small inactive indicator dots for all unselected bands
    _drawSmallDot(canvas, size, 'high_pass', eqState.highPass.frequency.value.toDouble(), 0.0, eqState.highPass.enabled.value);
    _drawSmallDot(canvas, size, 'low_shelf', eqState.lowShelf.frequency.value.toDouble(), eqState.lowShelf.uiGain.toDouble(), !eqState.lowShelf.isBypassed);
    _drawSmallDot(canvas, size, 'low', eqState.low.frequency.value.toDouble(), eqState.low.uiGain.toDouble(), !eqState.low.isBypassed);
    _drawSmallDot(canvas, size, 'mid', eqState.mid.frequency.value.toDouble(), eqState.mid.uiGain.toDouble(), !eqState.mid.isBypassed);
    _drawSmallDot(canvas, size, 'high', eqState.high.frequency.value.toDouble(), eqState.high.uiGain.toDouble(), !eqState.high.isBypassed);
    _drawSmallDot(canvas, size, 'high_shelf', eqState.highShelf.frequency.value.toDouble(), eqState.highShelf.uiGain.toDouble(), !eqState.highShelf.isBypassed);

    // Draw the active band dot on top
    if (activeBandKey != null) {
      _drawActiveBandDot(canvas, size);
    }
  }

  void _drawSmallDot(Canvas canvas, Size size, String bandKey, double freq, double db, bool isActive) {
    if (bandKey == activeBandKey) return;

    final double x = freqToX(freq, size.width);
    final double y = dbToY(db, size.height);

    final Paint fillPaint = Paint()
      ..color = isActive ? Colors.cyanAccent.withOpacity(0.5) : Colors.white38
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), 4.0, fillPaint);
  }

  void _drawActiveBandDot(Canvas canvas, Size size) {
    double freq = 1000;
    double db = 0;
    bool isActive = true;

    switch (activeBandKey) {
      case 'high_pass':
        freq = eqState.highPass.frequency.value.toDouble();
        isActive = eqState.highPass.enabled.value;
        break;
      case 'low_shelf':
        freq = eqState.lowShelf.frequency.value.toDouble();
        db = eqState.lowShelf.uiGain.toDouble();
        isActive = !eqState.lowShelf.isBypassed;
        break;
      case 'low':
        freq = eqState.low.frequency.value.toDouble();
        db = eqState.low.uiGain.toDouble();
        isActive = !eqState.low.isBypassed;
        break;
      case 'mid':
        freq = eqState.mid.frequency.value.toDouble();
        db = eqState.mid.uiGain.toDouble();
        isActive = !eqState.mid.isBypassed;
        break;
      case 'high':
        freq = eqState.high.frequency.value.toDouble();
        db = eqState.high.uiGain.toDouble();
        isActive = !eqState.high.isBypassed;
        break;
      case 'high_shelf':
        freq = eqState.highShelf.frequency.value.toDouble();
        db = eqState.highShelf.uiGain.toDouble();
        isActive = !eqState.highShelf.isBypassed;
        break;
    }

    final double x = freqToX(freq, size.width);
    final double y = dbToY(db, size.height);

    final Paint glowPaint = Paint()
      ..color = isActive ? Colors.cyanAccent.withOpacity(0.3) : Colors.white24
      ..style = PaintingStyle.fill;

    final Paint fillPaint = Paint()
      ..color = isActive ? Colors.cyanAccent : Colors.grey.shade400
      ..style = PaintingStyle.fill;

    final Paint outlinePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(Offset(x, y), 16.0, glowPaint);
    canvas.drawCircle(Offset(x, y), 8.0, fillPaint);
    canvas.drawCircle(Offset(x, y), 8.0, outlinePaint);
  }

  void _drawGridAndLabels(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    final textStyle = const TextStyle(color: Colors.white54, fontSize: 10);

    final yZero = dbToY(0, size.height);
    canvas.drawLine(Offset(0, yZero), Offset(size.width, yZero), Paint()..color = Colors.white30..strokeWidth = 1.5);

    _drawText(canvas, '+12', Offset(4, dbToY(12, size.height) - 6), textStyle);
    _drawText(canvas, '-12', Offset(4, dbToY(-12, size.height) - 6), textStyle);

    final List<int> gridFreqs = [20, 50, 100, 500, 1000, 5000, 10000, 20000];
    for (var f in gridFreqs) {
      final x = freqToX(f.toDouble(), size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      String label = f >= 1000 ? '${f ~/ 1000}k' : '$f';
      _drawText(canvas, label, Offset(x + 4, size.height - 16), textStyle);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, offset);
  }

  double _calcHighPassGain(double f, {bool forceActive = false}) {
    if (!forceActive && !eqState.highPass.enabled.value) return 0.0;
    final double fc = eqState.highPass.frequency.value.toDouble();
    final int order = (fc <= 4.0) ? 1 : 2;
    return -10.0 * (log(1.0 + pow(fc / f, 2 * order)) / ln10);
  }

  double _calcShelfGain(double f, ShelfFilter filter, bool isLowShelf, {bool useUiGain = false}) {
    if (!useUiGain && filter.isBypassed) return 0.0;
    final double gain = useUiGain ? filter.uiGain.toDouble() : filter.gain.value.toDouble();
    if (gain == 0) return 0.0;
    final double fc = filter.frequency.value.toDouble();
    if (isLowShelf) {
      return gain / (1.0 + pow(f / fc, 3.0));
    } else {
      return gain / (1.0 + pow(fc / f, 3.0));
    }
  }

  double _calcParametricGain(double f, ParametricEqBand band, {bool useUiGain = false}) {
    if (!useUiGain && band.isBypassed) return 0.0;
    final double gain = useUiGain ? band.uiGain.toDouble() : band.gain.value.toDouble();
    if (gain == 0) return 0.0;
    final double fc = band.frequency.value.toDouble();
    final double q = band.band.value == 'wide' ? 0.75 : 1.8;
    final double logDist = log(f / fc);
    return gain * exp(-(logDist * logDist) * (q * 4.0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
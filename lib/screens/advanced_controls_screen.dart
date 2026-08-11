import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../widgets/volume_slider.dart';

class AdvancedControlsScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const AdvancedControlsScreen({super.key, required this.service});

  @override
  State<AdvancedControlsScreen> createState() => _AdvancedControlsScreenState();
}

class _AdvancedControlsScreenState extends State<AdvancedControlsScreen> {
  bool? wasLineMono;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Controls')),
      body: StreamBuilder<MixerState>(
        stream: widget.service.stateStream,
        builder: (context, snapshot) {
          final state = snapshot.data ?? MixerState();

          final bool isXlr = state.routing.micToPga.value;
          final String inputSource = isXlr ? 'xlr' : 'jack';

          final bool isLineStereo = state.routing.lineStereoToPga.value;
          final String inputMode = isLineStereo ? 'stereo' : 'mono';

          final bool isOutputMono = state.mixer.mono.value;
          final String outputMode = isOutputMono ? 'mono' : 'stereo';

          final bool isGroundLifted = state.device.groundLiftEnabled.value;

          if (!isXlr && wasLineMono == null) {
            wasLineMono = state.routing.lineMonoToPga.value;
          }

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              const Text(
                'Input Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(height: 16),

              const Text('Source Selection'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                segments: [
                  ButtonSegment(
                    value: 'xlr',
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CustomPaint(
                              painter: XlrConnectorPainter(
                                isDetected: state.device.inputXlrDetected.value,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'XLR',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: 'jack',
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 28,
                            child: CustomPaint(
                              painter: JackConnectorPainter(
                                isDetected:
                                    state.device.inputJackDetected.value,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '1/4" Jack',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                selected: {inputSource},
                onSelectionChanged: (set) {
                  final String newSource = set.first;
                  if (newSource == 'xlr') {
                    widget.service.sendCommands({
                      state.routing.micToPga.command: 't',
                      state.routing.lineMonoToPga.command: 'f',
                      state.routing.lineStereoToPga.command: 'f',
                    });
                  } else {
                    bool isMono = inputMode == 'mono';
                    if (isXlr && wasLineMono != null) {
                      isMono = wasLineMono!;
                    }

                    widget.service.sendCommands({
                      state.routing.micToPga.command: 'f',
                      state.routing.lineMonoToPga.command: isMono ? 't' : 'f',
                      state.routing.lineStereoToPga.command: !isMono
                          ? 't'
                          : 'f',
                    });

                    wasLineMono = isMono;
                  }
                },
              ),
              const SizedBox(height: 24),

              const Text('Input Mode'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'stereo',
                    label: Text(
                      'Stereo / Unbalanced',
                      textAlign: TextAlign.center,
                    ),
                    tooltip: !isXlr
                        ? null
                        : 'Stereo is only available for the 1/4" TRS Jack input. Although it is possible to send a stereo signal over a single XLR cable, it is in the same category as walking outside on your socks. Therefore, by not supporting it, we encourage good behaviour.',
                  ),
                  ButtonSegment(
                    value: 'mono',
                    label: Text('Mono / Balanced', textAlign: TextAlign.center),
                  ),
                ],
                selected: {inputMode},
                onSelectionChanged: isXlr
                    ? null
                    : (set) {
                        final String newMode = set.first;
                        final bool isMono = newMode == 'mono';
                        widget.service.sendCommands({
                          state.routing.micToPga.command: 'f',
                          state.routing.lineMonoToPga.command: isMono
                              ? 't'
                              : 'f',
                          state.routing.lineStereoToPga.command: !isMono
                              ? 't'
                              : 'f',
                        });

                        wasLineMono = isMono;
                      },
              ),
              const SizedBox(height: 24),

              VolumeSlider(
                service: widget.service,
                input: state.pga.gain,
                label: 'Input Gain',
                valueLabelDecimals: 2,
                min: -12.0,
                max: 35.25,
                stepSize: 0.75,
              ),

              const Divider(height: 48),

              const Text(
                'Output Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(height: 16),

              const Text('Output Mode'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'stereo',
                    label: Text(
                      'Stereo / Unbalanced',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ButtonSegment(
                    value: 'mono',
                    label: Text('Mono / Balanced', textAlign: TextAlign.center),
                  ),
                ],
                selected: {outputMode},
                onSelectionChanged: (set) {
                  final String newMode = set.first;
                  if (newMode == 'mono') {
                    widget.service.sendCommands({
                      state.mixer.mono.command: 't',
                      state.speaker.balanced.command: 't',
                    });
                  } else {
                    widget.service.sendCommands({
                      state.mixer.mono.command: 'f',
                      state.speaker.balanced.command: 'f',
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              VolumeSlider(
                service: widget.service,
                input: state.speaker.volume,
                label: 'Master Output Volume',
                min: -57,
                max: 6,
              ),

              const SizedBox(height: 24),

              IntrinsicHeight(
                // 1. Added IntrinsicHeight here
                child: Row(
                  spacing: 12.0,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // 2. Added stretch alignment
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withAlpha(50)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        // Centers the painter vertically
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CustomPaint(
                              painter: XlrConnectorPainter(
                                isDetected:
                                    state.device.outputXlrDetected.value,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CustomPaint(
                                painter: GroundSymbolPainter(
                                  isLifted: isGroundLifted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                // Centers text vertically
                                children: [
                                  Text(
                                    isGroundLifted
                                        ? 'Ground Lifted'
                                        : 'Ground Connected',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LARGE FRONT-VIEW XLR CONNECTOR PAINTER
// -----------------------------------------------------------------------------
class XlrConnectorPainter extends CustomPainter {
  final bool isDetected;

  XlrConnectorPainter({required this.isDetected});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, size.height / 2);
    final Color mainColor = isDetected ? Colors.greenAccent : Colors.white70;

    // Outer Circle Shell
    final Paint outerPaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius - 2, outerPaint);

    // Inner Notch (Top of XLR socket)
    final Paint notchPaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;
    final Path notchPath = Path()
      ..addRect(Rect.fromLTWH(center.dx - 2.5, center.dy - radius + 2, 5, 4));
    canvas.drawPath(notchPath, notchPaint);

    // 3 Female Socket Pins
    final Paint pinPaint = Paint()
      ..color = mainColor
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
  bool shouldRepaint(covariant XlrConnectorPainter oldDelegate) =>
      oldDelegate.isDetected != isDetected;
}

// -----------------------------------------------------------------------------
// LARGE SIDE-VIEW 1/4" JACK CONNECTOR PAINTER
// -----------------------------------------------------------------------------
class JackConnectorPainter extends CustomPainter {
  final bool isDetected;

  JackConnectorPainter({required this.isDetected});

  @override
  void paint(Canvas canvas, Size size) {
    final Color mainColor = isDetected ? Colors.greenAccent : Colors.white70;
    final Paint strokePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = mainColor
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
  bool shouldRepaint(covariant JackConnectorPainter oldDelegate) =>
      oldDelegate.isDetected != isDetected;
}

class GroundSymbolPainter extends CustomPainter {
  final bool isLifted;

  GroundSymbolPainter({required this.isLifted});

  @override
  void paint(Canvas canvas, Size size) {
    final Color strokeColor = isLifted ? Colors.amber : Colors.white70;
    final Paint linePaint = Paint()
      ..color = strokeColor
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
  bool shouldRepaint(covariant GroundSymbolPainter oldDelegate) =>
      oldDelegate.isLifted != isLifted;
}

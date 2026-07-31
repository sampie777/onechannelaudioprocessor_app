import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../widgets/audio_meter.dart';
import 'connection_screen.dart';
import 'eq_screen.dart';

class MixerScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const MixerScreen({super.key, required this.service});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  bool _isManualDisconnect = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;

  @override
  void initState() {
    super.initState();
    // Listen for unexpected disconnections
    widget.service.addListener(_onConnectionStateChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onConnectionStateChanged);
    super.dispose();
  }

  void _onConnectionStateChanged() {
    // 1. Connection Restored / Is Active
    if (widget.service.isConnected) {
      if (_isReconnecting && mounted) {
        setState(() {
          _isReconnecting = false;
          _reconnectAttempts = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconnected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // 2. Ignore expected drops (user clicked disconnect)
    if (_isManualDisconnect) return;

    // 3. Unexpected drop detected! Start loop if not already running.
    if (!_isReconnecting && mounted) {
      _startAutoReconnect();
    }
  }

  Future<void> _startAutoReconnect() async {
    setState(() {
      _isReconnecting = true;
      _reconnectAttempts = 0;
    });

    for (int i = 1; i <= 3; i++) {
      // Abort loop if user manually clicks disconnect while reconnecting
      if (!mounted || _isManualDisconnect) return;

      setState(() => _reconnectAttempts = i);

      try {
        await Future.delayed(const Duration(seconds: 2));
        await widget.service.reconnect();

        // If reconnect() didn't throw an error, it succeeded!
        // The listener will catch the success and clear the UI.
        return;
      } catch (e) {
        // Attempt failed, loop continues
      }
    }

    // 4. If we reach here, all 3 attempts failed.
    if (mounted && !_isManualDisconnect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection lost permanently.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConnectionScreen(service: widget.service),
        ),
      );
    }
  }

  Future<void> _handleManualDisconnect() async {
    setState(() => _isManualDisconnect = true);
    await widget.service.disconnect();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConnectionScreen(service: widget.service),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniMixer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Equalizer',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EqScreen(service: widget.service),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: 'Disconnect',
            onPressed: _handleManualDisconnect,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background: The standard Mixer UI
          StreamBuilder<MixerState>(
            stream: widget.service.stateStream,
            builder: (context, snapshot) {
              final state = snapshot.data ?? MixerState();

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // --- AUDIO METER + SCALE ---
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AudioMeterWidget(
                            peakLinear: state.peakOverPeriod,
                            avgPeakLinear: state.avgPeakOverPeriod,
                          ),
                        ),
                      ],
                    ),

                    // Volume Fader Column
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            // ⬇️ THIS IS THE MAGIC FIX ⬇️
                            // Forces the CustomPaint to match the exact height of the Slider!
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // The Fader
                              SizedBox(
                                width: 90, // Matches the faderLength so it doesn't clip
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 12.0,
                                    activeTrackColor: Colors.cyan,
                                    inactiveTrackColor: Colors.grey.shade800,
                                    thumbShape: const FaderThumbShape(
                                      faderWidth: 32.0,
                                      faderLength: 80.0,
                                    ),
                                    // By setting the overlay to 24, we lock the internal padding
                                    // of the slider so our math aligns perfectly!
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
                                  ),
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Slider(
                                      value: state.speaker.volume.value.toDouble(),
                                      min: -57.0,
                                      max: 6.0,
                                      divisions: 63,
                                      onChanged: (val) {
                                        widget.service.sendCommands({'speaker.volume': val.toInt().toString()});
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              // The Scale Labels
                              SizedBox(
                                width: 40,
                                child: CustomPaint(
                                  painter: FaderScalePainter(
                                    min: -57.0,
                                    max: 6.0,
                                    ticks: [6, 0, -5, -10, -20, -40],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${state.speaker.volume.value} dB',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'MUTE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        IconButton.filled(
                          iconSize: 32,
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            minimumSize: const Size(64, 64),
                            backgroundColor: state.speaker.mute.value
                                ? Colors.red.shade900.withAlpha(128)
                                : Colors.cyan.withAlpha(51),
                            foregroundColor: state.speaker.mute.value
                                ? Colors.redAccent
                                : Colors.cyanAccent,
                          ),
                          icon: Icon(state.speaker.mute.value ? Icons.volume_off : Icons.volume_up),
                          onPressed: () {
                            widget.service.sendCommands({'speaker.mute': state.speaker.mute.value ? 'f' : 't'});
                          },
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          ),

          // Foreground: Reconnecting Overlay
          if (_isReconnecting)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      'Reconnecting...',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Attempt $_reconnectAttempts of 3',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------------------
// CUSTOM FADER SCALE PAINTER
// -----------------------------------------------------------------------------
class FaderScalePainter extends CustomPainter {
  final double min;
  final double max;
  final List<double> ticks;

  // Must match the overlayRadius of the SliderTheme
  final double sliderPadding = 30.0;

  // ⬇️ ADJUST THIS OFFSET TO SHIFT THE SCALE UP/DOWN ⬇️
  final double topOffset = 0.0;

  FaderScalePainter({required this.min, required this.max, required this.ticks});

  @override
  void paint(Canvas canvas, Size size) {
    final double trackLength = size.height - (sliderPadding * 2);
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final tick in ticks) {
      final fraction = (tick - min) / (max - min);

      // Added the topOffset here so the whole scale shifts down
      final y = size.height - sliderPadding - (fraction * trackLength) + topOffset;

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

// -----------------------------------------------------------------------------
// CUSTOM FADER THUMB SHAPE
// -----------------------------------------------------------------------------
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

import 'package:flutter/material.dart';

import 'audio_fader_scales.dart';

class AudioFaderWidget extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool isMuted;
  final ValueChanged<double> onChanged;
  final VoidCallback onMuteToggled;
  final List<double> scaleTicks;

  const AudioFaderWidget({
    super.key,
    required this.value,
    this.min = -57.0,
    this.max = 6.0,
    this.divisions = 63,
    required this.isMuted,
    required this.onChanged,
    required this.onMuteToggled,
    this.scaleTicks = const [6, 0, -5, -10, -20, -40],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Fader + Scale
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The Slider Fader
              SizedBox(
                width: 90,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12.0,
                    activeTrackColor: Colors.cyan,
                    inactiveTrackColor: Colors.grey.shade800,
                    thumbShape: const FaderThumbShape(
                      faderWidth: 32.0,
                      faderLength: 80.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 24.0,
                    ),
                  ),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: value.clamp(min, max),
                      min: min,
                      max: max,
                      divisions: divisions,
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ),
              // The Scale Labels
              SizedBox(
                width: 40,
                child: CustomPaint(
                  painter: FaderScalePainter(
                    min: min,
                    max: max,
                    ticks: scaleTicks,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // dB Readout
        Text(
          '${value.toInt()} dB',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        // Mute Label & Button
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
            backgroundColor: isMuted
                ? Colors.red.shade900.withAlpha(128)
                : Colors.cyan.withAlpha(51),
            foregroundColor: isMuted ? Colors.redAccent : Colors.cyanAccent,
          ),
          icon: Icon(
            isMuted ? Icons.volume_off : Icons.volume_up,
          ),
          onPressed: onMuteToggled,
        ),
      ],
    );
  }
}
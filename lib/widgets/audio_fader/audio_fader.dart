import 'package:flutter/material.dart';

import 'audio_fader_scales.dart';
import 'audio_mute_button.dart';

class AudioFaderWidget extends StatelessWidget {
  final double value;
  final bool? isMuted;
  final bool showVolumeValueText;
  final ValueChanged<double> onChanged;
  final VoidCallback? onMuteToggled;
  final List<double> scaleTicks;

  const AudioFaderWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.isMuted,
    this.onMuteToggled,
    this.scaleTicks = const [-60.0, -40.0, -20.0, -10.0, -5.0, 0.0, 6.0],
    this.showVolumeValueText = true,
  });

  @override
  Widget build(BuildContext context) {
    // Convert incoming raw dB value to the continuous 0.0 - 1.0 fraction
    final sliderFraction = dbToLinear(scaleTicks, value);

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
                      value: sliderFraction, // Now uses 0.0 - 1.0 mapping
                      min: 0.0,
                      max: 1.0,
                      // Removed 'divisions' to allow a smooth analog feel
                      onChanged: (fraction) {
                        // Map the fraction back to dB, round to integer, and broadcast
                        final mappedDb = linearToDb(
                          scaleTicks,
                          fraction,
                        ).roundToDouble();
                        onChanged(mappedDb);
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
                    ticks: scaleTicks,
                    faderStops: scaleTicks,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showVolumeValueText) ...[
          const SizedBox(height: 16),
          // dB Readout
          Text(
            '${value.toInt()} dB',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
        const SizedBox(height: 16),

        isMuted != null && onMuteToggled != null
            ? AudioMuteButton(isMuted: isMuted!, onMuteToggled: onMuteToggled!)
            : const SizedBox(height: 87),
      ],
    );
  }
}

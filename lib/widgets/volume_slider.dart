import 'package:flutter/material.dart';
import 'package:onechannelaudioprocessor/models/mixer_state.dart';

import '../services/esp32_connection_service.dart';

class VolumeSlider<T extends num> extends StatelessWidget {
  final Esp32ConnectionService service;
  final Lockable input;
  final String? label;
  final bool showValue;
  final T min;
  final T max;
  final double stepSize;
  final int? valueLabelDecimals;

  const VolumeSlider({
    super.key,
    required this.service,
    required this.input,
    required this.min,
    required this.max,
    this.label,
    this.showValue = true,
    this.stepSize = 1.0,
    this.valueLabelDecimals,
  });

  @override
  Widget build(BuildContext context) {
    String finalLabel = "";
    if (label != null) finalLabel = label!;
    if (label != null && showValue) finalLabel += ': ';
    if (showValue) {
      if (T == double && valueLabelDecimals != null) {
        finalLabel +=
            '${(input.value as double).toStringAsFixed(valueLabelDecimals!)} dB';
      } else {
        finalLabel += '${input.value} dB';
      }
    }

    // Convert to double for the Slider widget requirements
    final double doubleValue = (input.value as num).toDouble();
    final double doubleMin = min.toDouble();
    final double doubleMax = max.toDouble();

    return Column(
      children: [
        if (finalLabel.isNotEmpty) Text(finalLabel),

        // Use LayoutBuilder to get the exact width of the parent container
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate the fractional position of 0 dB (0.0 to 1.0)
            final double fraction = (0.0 - doubleMin) / (doubleMax - doubleMin);

            // The default horizontal padding of a Material Slider is 24px on each side
            const double trackPadding = 26.0;
            final double trackWidth = constraints.maxWidth - (trackPadding * 2);
            final double leftPosition = trackPadding + (trackWidth * fraction);

            return Stack(
              alignment: Alignment.center,
              children: [
                // Only draw the tick mark if 0 dB is actually within the slider's range
                if (doubleMin <= 0 && doubleMax >= 0)
                  Positioned(
                    left: leftPosition - 1, // Offset by half the line width (2px) to center it
                    child: Container(
                      width: 2,
                      height: 30, // Slightly taller than the slider track
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(150),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),

                // The main Slider
                Slider(
                  value: doubleValue.clamp(doubleMin, doubleMax),
                  min: doubleMin,
                  max: doubleMax,
                  divisions: ((doubleMax - doubleMin) / stepSize).toInt(),
                  activeColor: Colors.cyan,
                  onChanged: (val) {
                    final typedVal = T == int ? val.toInt() : val;
                    service.sendCommands({input.command: typedVal.toString()});
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

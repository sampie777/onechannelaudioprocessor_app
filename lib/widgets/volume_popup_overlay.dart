import 'package:flutter/material.dart';

import 'audio_fader/audio_fader_scales.dart';

class VolumePopupOverlay extends StatelessWidget {
  final bool isVisible;
  final double volumeDb;
  final List<double> scaleTicks;

  const VolumePopupOverlay({
    super.key,
    required this.isVisible,
    required this.volumeDb,
    this.scaleTicks = const [-127.0, -80.0, -40.0, -20.0, -10.0, -5.0, 0.0],
  });

  @override
  Widget build(BuildContext context) {
    // Calculate volume fraction using the piecewise logic to match the fader
    final double volFraction = dbToLinear(scaleTicks, volumeDb);

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha(240),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withAlpha(50)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(100),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.volume_up,
                    color: Colors.cyan,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Main Volume',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${volumeDb.toInt()} dB',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: volFraction,
                          backgroundColor: Colors.grey.withAlpha(80),
                          color: Colors.cyan,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
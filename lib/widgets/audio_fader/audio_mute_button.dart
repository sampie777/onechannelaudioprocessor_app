import 'package:flutter/material.dart';

class AudioMuteButton extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onMuteToggled;

  const AudioMuteButton({
    super.key,
    required this.isMuted,
    required this.onMuteToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
          icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
          onPressed: onMuteToggled,
        ),
      ],
    );
  }
}

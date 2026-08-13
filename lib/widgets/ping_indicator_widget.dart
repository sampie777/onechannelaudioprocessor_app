import 'package:flutter/material.dart';

class PingIndicatorWidget extends StatelessWidget {
  final int pingMs;

  const PingIndicatorWidget({super.key, required this.pingMs});

  Color _getPingColor() {
    if (pingMs <= 0) return Colors.grey;
    if (pingMs < 50) return Colors.greenAccent;
    if (pingMs < 120) return Colors.amber;
    return Colors.redAccent;
  }

  IconData _getPingIcon() {
    if (pingMs <= 0) return Icons.wifi_off;
    if (pingMs < 50) return Icons.wifi;
    if (pingMs < 120) return Icons.wifi_2_bar;
    return Icons.wifi_1_bar;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getPingColor();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_getPingIcon(), color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          pingMs > 0 ? '${pingMs}ms' : '--',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
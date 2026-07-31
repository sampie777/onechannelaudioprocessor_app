import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../widgets/audio_meter.dart';
import 'connection_screen.dart';

class MixerScreen extends StatefulWidget {
  final Esp32ConnectionService service;
  const MixerScreen({super.key, required this.service});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  bool _isMuted = false;
  double _volume = 0.0;
  bool _isManualDisconnect = false;

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
    // If the service loses connection, navigate back to connection screen
    if (!widget.service.isConnected && mounted) {
      if (!_isManualDisconnect) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection lost. Please reconnect.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

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
    // _onConnectionStateChanged will trigger navigation quietly without a SnackBar
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    widget.service.sendCommands({'speaker.mute': _isMuted ? 't' : 'f'});
  }

  void _onVolumeChanged(double val) {
    setState(() => _volume = val);
    widget.service.sendCommands({'speaker.volume': val.toInt().toString()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniMixer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: 'Disconnect',
            onPressed: _handleManualDisconnect,
          )
        ],
      ),
      body: StreamBuilder<MixerState>(
        stream: widget.service.stateStream,
        builder: (context, snapshot) {
          final state = snapshot.data ?? MixerState();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Audio Meter Column
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AudioMeterWidget(
                      peakLinear: state.peakOverPeriod,
                      avgPeakLinear: state.avgPeakOverPeriod,
                    ),
                    const SizedBox(height: 12),
                    Text('${state.avgPeakDbfs.toStringAsFixed(1)} dBFS',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),

                // Volume Fader Column
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: _volume,
                          min: -57.0,
                          max: 6.0,
                          divisions: 63,
                          label: '${_volume.toInt()} dB',
                          onChanged: _onVolumeChanged,
                        ),
                      ),
                    ),
                    Text('${_volume.toInt()} dB', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    IconButton.filled(
                      iconSize: 32,
                      icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                      color: _isMuted ? Colors.red : Colors.green,
                      onPressed: _toggleMute,
                    ),
                    const SizedBox(height: 8),
                    Text(_isMuted ? 'MUTED' : 'ACTIVE', style: const TextStyle(fontSize: 12)),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
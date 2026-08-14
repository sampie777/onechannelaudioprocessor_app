import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import 'connection_screen.dart';

class DeviceSettingsScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const DeviceSettingsScreen({super.key, required this.service});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _hasInitialSsidSet = false;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _sendWifiCredentials() {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    widget.service.sendCommands({
      WifiState().ssid.command: ssid,
      'wifi.password': password,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Wi-Fi credentials updated.')));
  }

  void _copyIpToClipboard(String ip) {
    Clipboard.setData(ClipboardData(text: ip));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied IP $ip to clipboard.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _switchToIp(String ip) async {
    await widget.service.disconnect();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            ConnectionScreen(service: widget.service, autoConnectIp: ip),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Settings')),
      body: StreamBuilder<MixerState>(
        stream: widget.service.stateStream,
        builder: (context, snapshot) {
          final state = snapshot.data ?? MixerState();

          // Initialize controller with current state SSID once upon loading
          if (!_hasInitialSsidSet && snapshot.hasData) {
            _ssidController.text = state.wifi.ssid.value;
            _hasInitialSsidSet = true;
          }

          int updateInterval = state.client.smallUpdateIntervalMs.value;
          final String staIp = widget.service.activeType == ConnectionType.demo
              ? ""
              : state.wifi.ip.value;
          final bool isCurrentlyConnectedToStaIp =
              widget.service.activeType == ConnectionType.wifi &&
              widget.service.connectedIpAddress == staIp;

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // Wi-Fi Section
              const Text(
                'Network (external Wi-Fi)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan,
                ),
              ),
              const Text(
                'Leave empty to disable external Wi-Fi',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: 'Wi-Fi SSID',
                  prefixIcon: Icon(Icons.wifi_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _sendWifiCredentials,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Update Wi-Fi & Connect'),
              ),

              // Assigned STA IP Banner & Switch Controls
              if (staIp.isNotEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  color: Colors.cyan.withAlpha(25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.cyan.withAlpha(80)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lan_outlined,
                              size: 18,
                              color: Colors.cyan,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Reachable on IP:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.cyan,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                staIp,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              tooltip: 'Copy IP',
                              onPressed: () => _copyIpToClipboard(staIp),
                            ),
                          ],
                        ),
                        if (!isCurrentlyConnectedToStaIp) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.swap_horiz_rounded),
                              label: const Text('Connect to this IP'),
                              onPressed: () => _switchToIp(staIp),
                            ),
                          ),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Currently active connection',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const Divider(height: 48),

              // Device Section
              const Text(
                'Device Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  state.device.enableStatusLights.value
                      ? Icons.lightbulb
                      : Icons.lightbulb_outline,
                ),
                title: const Text('Status LEDs'),
                subtitle: const Text(
                  'Enable or disable hardware indicator lights',
                  style: TextStyle(color: Colors.grey),
                ),
                value: state.device.enableStatusLights.value,
                activeThumbColor: Colors.cyan,
                onChanged: (val) {
                  widget.service.sendCommands({
                    state.device.enableStatusLights.command: val ? 't' : 'f',
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Transform.rotate(
                  angle: (180 + 45) * math.pi / 180,
                  child: Icon(
                    state.device.autoSwitchInputMode.value
                        ? Icons.auto_fix_off
                        : Icons.auto_fix_off_outlined,
                  ),
                ),
                title: const Text('Auto-switch Input Source'),
                subtitle: const Text(
                  'Automatically switch input when an XLR or Jack cable is plugged in',
                  style: TextStyle(color: Colors.grey),
                ),
                value: state.device.autoSwitchInputMode.value,
                activeThumbColor: Colors.cyan,
                onChanged: (val) {
                  widget.service.sendCommands({
                    state.device.autoSwitchInputMode.command: val ? 't' : 'f',
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Transform.rotate(
                  angle: 45 * math.pi / 180,
                  child: Icon(
                    state.device.autoSwitchOutputMode.value
                        ? Icons.auto_fix_off
                        : Icons.auto_fix_off_outlined,
                  ),
                ),
                title: const Text('Auto-switch Output Mode'),
                subtitle: const Text(
                  'Automatically adapt output channel & balancing configuration when an output cable is plugged in',
                  style: TextStyle(color: Colors.grey),
                ),
                value: state.device.autoSwitchOutputMode.value,
                activeThumbColor: Colors.cyan,
                onChanged: (val) {
                  widget.service.sendCommands({
                    state.device.autoSwitchOutputMode.command: val ? 't' : 'f',
                  });
                },
              ),
              const SizedBox(height: 16),

              // Update Interval Section
              Row(
                children: [
                  const Icon(Icons.speed_rounded, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('VU Meter Update Interval: ${updateInterval}ms'),
                ],
              ),
              Slider(
                value: updateInterval.toDouble().clamp(50, 1000),
                min: 50,
                max: 1000,
                divisions: ((1000 - 50) / 50).toInt(),
                label: '${updateInterval}ms',
                onChanged: (val) {
                  // Only update UI locally during drag, send on end to prevent network spam
                  state.client.smallUpdateIntervalMs.value = val.toInt();
                },
                onChangeEnd: (val) {
                  widget.service.sendCommands({
                    state.client.smallUpdateIntervalMs.command: val
                        .toInt()
                        .toString(),
                  });
                },
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Device state version: ${state.stateVersion ?? 'none'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.copyright, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Samuel-Anton Jansen',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../services/esp32_connection_service.dart';
import 'mixer_screen.dart';

class ConnectionScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const ConnectionScreen({super.key, required this.service});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  static const String _recentIpsKey = 'recent_ip_addresses';
  static const String _espSoftApSsid = 'OneChannelAudioProcessor';

  ConnectionType _selectedType = ConnectionType.wifi;
  final TextEditingController _ipController = TextEditingController(
    text: "192.168.1.100",
  );

  List<String> _recentIps = [];
  bool _isLoading = false;

  // Direct AP Scanning state
  bool _isScanningDirect = false;
  bool? _isDirectApAvailable;

  bool get _isNativeMobileApp =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();

    final lastConnectionType = widget.service.lastConnectionType;
    if (lastConnectionType != null) {
      setState(() {
        _selectedType = lastConnectionType;
      });
    }

    _loadSavedIps();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOAD & SAVE RECENT IPS
  // ---------------------------------------------------------------------------
  Future<void> _loadSavedIps() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIps = prefs.getStringList(_recentIpsKey) ?? [];

    setState(() {
      _recentIps = savedIps;
      if (_recentIps.isNotEmpty) {
        _ipController.text = _recentIps.first;
      } else {
        _ipController.text = "192.168.1.50";
      }
    });
  }

  Future<void> _saveSuccessfulIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> updatedList = List.from(_recentIps);
    updatedList.remove(ip);
    updatedList.insert(0, ip);

    // Keep top unique recent entries
    if (updatedList.length > 5) {
      updatedList = updatedList.sublist(0, 5);
    }

    await prefs.setStringList(_recentIpsKey, updatedList);

    setState(() {
      _recentIps = updatedList;
    });
  }

  // ---------------------------------------------------------------------------
  // SCAN FOR NEARBY SOFTAP WITH `wifi_scan`
  // ---------------------------------------------------------------------------
  Future<void> _checkDirectApAvailability() async {
    setState(() {
      _isScanningDirect = true;
      _isDirectApAvailable = null;
    });

    try {
      // 1. Check if scanning capabilities are enabled (requests permissions if askPermissions is true)
      final canStart = await WiFiScan.instance.canStartScan(
        askPermissions: true,
      );
      if (canStart != CanStartScan.yes) {
        dev.log("Cannot start Wi-Fi scan: $canStart");
        if (mounted) {
          setState(() {
            _isDirectApAvailable = false;
            _isScanningDirect = false;
          });
        }
        return;
      }

      // 2. Trigger active scan
      await WiFiScan.instance.startScan();

      // 3. Verify capability to retrieve scanned results
      final canGetResults = await WiFiScan.instance.canGetScannedResults(
        askPermissions: true,
      );
      if (canGetResults != CanGetScannedResults.yes) {
        dev.log("Cannot retrieve scan results: $canGetResults");
        if (mounted) {
          setState(() {
            _isDirectApAvailable = false;
            _isScanningDirect = false;
          });
        }
        return;
      }

      // 4. Fetch scan results and check for target SSID
      final accessPoints = await WiFiScan.instance.getScannedResults();
      final bool foundTargetAp = accessPoints.any(
        (ap) => ap.ssid == _espSoftApSsid,
      );

      if (mounted) {
        setState(() {
          _isDirectApAvailable = foundTargetAp;
          _isScanningDirect = false;
        });
      }
    } catch (e) {
      dev.log("Error during Wi-Fi scan", error: e);
      if (mounted) {
        setState(() {
          _isDirectApAvailable = false;
          _isScanningDirect = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // HANDLE CONNECT
  // ---------------------------------------------------------------------------
  Future<void> _handleConnect() async {
    dev.log("Start new connection attempt...");

    setState(() => _isLoading = true);
    try {
      if (_selectedType == ConnectionType.wifi) {
        final ip = _ipController.text.trim();
        if (ip.isEmpty) throw Exception("Please enter an IP address");

        await widget.service.connectWifi(ip);
        await _saveSuccessfulIp(ip);
      } else if (_selectedType == ConnectionType.direct) {
        const ip = "192.168.4.1";
        await widget.service.connectWifi(ip);
      } else if (_selectedType == ConnectionType.demo) {
        await widget.service.connectDemo();
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MixerScreen(service: widget.service),
          ),
        );
      }
    } catch (e) {
      dev.log("Failed to create a new connection", error: e);
      await widget.service.disconnect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract up to 2 unique last connected IPs
    final displayRecentIps = _recentIps.take(2).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('MiniMixer Connect'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // -------------------------------------------------------
                      // 1. WI-FI BUTTON & INPUT SECTION
                      // -------------------------------------------------------
                      _buildOptionTile(
                        type: ConnectionType.wifi,
                        title: 'Wi-Fi Network',
                        subtitle: 'Connect via local network router',
                        icon: Icons.wifi,
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox(width: double.infinity),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(
                            top: 12.0,
                            bottom: 8.0,
                            left: 8.0,
                            right: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _ipController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Mixer IP Address',
                                  hintText: '192.168.1.100',
                                  prefixIcon: const Icon(Icons.lan_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                ),
                              ),
                              if (displayRecentIps.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'Last Connected IPs:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: displayRecentIps.map((ip) {
                                    final bool isCurrent =
                                        _ipController.text == ip;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 6.0,
                                      ),
                                      child: ActionChip(
                                        avatar: Icon(
                                          Icons.history,
                                          size: 16,
                                          color: isCurrent
                                              ? theme.colorScheme.primary
                                              : Colors.grey,
                                        ),
                                        label: Text(
                                          ip,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        backgroundColor: isCurrent
                                            ? theme.colorScheme.primary
                                                  .withAlpha(40)
                                            : null,
                                        onPressed: () {
                                          setState(
                                            () => _ipController.text = ip,
                                          );
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        crossFadeState: _selectedType == ConnectionType.wifi
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                      const SizedBox(height: 12),

                      _buildOptionTile(
                        type: ConnectionType.direct,
                        title: 'Direct (SoftAP)',
                        subtitle:
                            'Connect directly to Mixer internal Wi-Fi Network',
                        icon: Icons.wifi_tethering,
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox(width: double.infinity),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(
                            top: 12.0,
                            bottom: 8.0,
                            left: 8.0,
                            right: 8.0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withAlpha(80),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Connect your phone to the Mixer Wi-Fi network "OneChannelAudioProcessor" before continuing.',
                                  style: TextStyle(fontSize: 13, height: 1.4),
                                ),

                                if (_isNativeMobileApp) ...[
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: _isScanningDirect
                                        ? null
                                        : _checkDirectApAvailability,
                                    icon: _isScanningDirect
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.refresh, size: 18),
                                    label: const Text('Check Network'),
                                  ),

                                  // Status message stacked cleanly underneath the button
                                  if (_isDirectApAvailable != null) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(
                                          _isDirectApAvailable!
                                              ? Icons.check_circle
                                              : Icons.error_outline,
                                          color: _isDirectApAvailable!
                                              ? Colors.green
                                              : Colors.orange,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _isDirectApAvailable!
                                                ? 'Network "$_espSoftApSsid" Found'
                                                : 'Network not detected',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: _isDirectApAvailable!
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                        crossFadeState: _selectedType == ConnectionType.direct
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                      const SizedBox(height: 12),

                      _buildOptionTile(
                        type: ConnectionType.demo,
                        title: 'Demo Mode',
                        subtitle: 'Offline simulation with mock telemetry',
                        icon: Icons.play_circle_outline,
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox(width: double.infinity),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(
                            top: 12.0,
                            bottom: 8.0,
                            left: 8.0,
                            right: 8.0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withAlpha(80),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Demo Mode runs completely offline with simulated audio meters. No hardware connection required.',
                              style: TextStyle(fontSize: 13, height: 1.3),
                            ),
                          ),
                        ),
                        crossFadeState: _selectedType == ConnectionType.demo
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                    ],
                  ),
                ),
              ),

              // ---------------------------------------------------------------
              // FIXED CONNECT BUTTON AT BOTTOM
              // ---------------------------------------------------------------
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleConnect,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text(
                        'CONNECT',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper builder for vertical rounded buttons
  Widget _buildOptionTile({
    required ConnectionType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _selectedType == type;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selectedType = type;
          });
          if (type == ConnectionType.direct) {
            _checkDirectApAvailability();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withAlpha(160)
                : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withAlpha(40),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? theme.colorScheme.primary : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer.withAlpha(
                                180,
                              )
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<ConnectionType>(
                value: type,
                groupValue: _selectedType,
                onChanged: (ConnectionType? val) {
                  if (val != null) {
                    setState(() => _selectedType = val);
                    if (val == ConnectionType.direct) {
                      _checkDirectApAvailability();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:onechannelaudioprocessor/services/udp_meter_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/mixer_state.dart';

enum ConnectionType { wifi, bluetooth, demo }

class Esp32ConnectionService extends ChangeNotifier {
  String? _lastIpAddress;
  String? _lastBtAddress;
  ConnectionType? _lastConnectionType;

  ConnectionType? _activeType;
  bool _isConnected = false;

  WebSocketChannel? _wsChannel;
  UdpMeterService? udpService;
  BluetoothConnection? _btConnection;

  // Demo Mode Members
  Timer? _demoTimer;
  final Random _random = Random();

  final _stateController = StreamController<MixerState>.broadcast();

  Stream<MixerState> get stateStream => _stateController.stream;
  final MixerState _currentMixerState = MixerState();

  bool get isConnected => _isConnected;

  ConnectionType? get activeType => _activeType;

  // ---------------------------------------------------------------------------
  // CONNECT VIA WI-FI (WebSocket)
  // ---------------------------------------------------------------------------
  Future<void> connectWifi(String ipAddress) async {
    dev.log("Connecting to IP address: $ipAddress");
    await disconnect();

    try {
      _lastIpAddress = ipAddress;
      _lastConnectionType = ConnectionType.wifi;

      final wsUrl = 'ws://$ipAddress/ws';

      final ws = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Device unreachable.');
        },
      );

      ws.pingInterval = const Duration(seconds: 3);

      // Wrap the successfully connected socket into the channel
      _wsChannel = IOWebSocketChannel(ws);

      _wsChannel!.stream.listen(
        (data) => _parseIncomingData(data.toString()),
        onError: (error) {
          dev.log("Error while listening to websocket: $error", error: error);
          disconnect();
        },
        onDone: () {
          dev.log("Websocket stream is done.");
          disconnect();
        },
      );

      udpService = UdpMeterService();
      udpService!.onMeterData = (double peak, double avg) {
        final json = {"peak_over_period": peak, "avg_peak_over_period": avg};
        _parseIncomingData(jsonEncode(json));
      };
      udpService!.startListening(5005);

      _activeType = ConnectionType.wifi;
      _isConnected = true;
      notifyListeners();
    } catch (e) {
      dev.log("Failed to connect to IP address: $ipAddress.");
      _isConnected = false;
      _wsChannel = null;
      notifyListeners();
      rethrow; // Throws back to the UI so the catch block dismisses the spinner
    }
  }

  // ---------------------------------------------------------------------------
  // CONNECT VIA BLUETOOTH SPP
  // ---------------------------------------------------------------------------
  Future<void> connectBluetooth(String address) async {
    dev.log("Connecting to Bluetooth device: $address.");

    await disconnect();
    try {
      _lastBtAddress = address;
      _lastConnectionType = ConnectionType.bluetooth;

      _btConnection = await BluetoothConnection.toAddress(address);
      _activeType = ConnectionType.bluetooth;
      _isConnected = true;
      notifyListeners();

      StringBuffer rxBuffer = StringBuffer();

      _btConnection!.input?.listen(
        (Uint8List data) {
          String chunk = utf8.decode(data);
          rxBuffer.write(chunk);

          // Process line-delimited JSON or curly bracket frames
          String content = rxBuffer.toString();
          if (content.contains('{') && content.contains('}')) {
            int lastIndex = content.lastIndexOf('}');
            String completeFrame = content.substring(0, lastIndex + 1);
            rxBuffer = StringBuffer(content.substring(lastIndex + 1));

            _parseIncomingData(completeFrame);
          }
        },
        onError: (error) {
          dev.log("Error while listening to Bluetooth", error: error);
          disconnect();
        },
        onDone: () {
          dev.log("Bluetooth connection is done");
          disconnect();
        },
      );
    } catch (e) {
      dev.log("Failed to connect to Bluetooth device: $address.");
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // CONNECT DEMO MODE
  // ---------------------------------------------------------------------------
  Future<void> connectDemo() async {
    dev.log("Launching Demo Mode.");
    await disconnect();

    _lastConnectionType = ConnectionType.demo;
    _activeType = ConnectionType.demo;
    _isConnected = true;
    notifyListeners();

    // Periodically generate simulated audio meter peaks
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isConnected || _activeType != ConnectionType.demo) return;

      // Generate random linear peak values between 0.0 and 1.0
      final double rawPeak = pow(_random.nextDouble(), 2).toDouble();
      final double avgPeak = (rawPeak * 0.6) + (_random.nextDouble() * 0.1);

      // Create update payload matching the json format
      final mockJson = {
        'peak_over_period': rawPeak.clamp(0.01, 1.0),
        'avg_peak_over_period': avgPeak.clamp(0.01, 1.0),
      };

      _parseIncomingData(jsonEncode(mockJson));
    });
  }

  // ---------------------------------------------------------------------------
  // SEND COMMAND FORMATTER: "speaker.mute=t&speaker.volume=0"
  // ---------------------------------------------------------------------------
  void sendCommands(Map<String, String> commands) {
    if (!_isConnected) return;

    _currentMixerState.updateFromCommands(commands);
    _stateController.add(_currentMixerState);

    if (_activeType == ConnectionType.demo) {
      // In demo mode, local state is already updated above, no socket needed
      return;
    }

    List<String> parts = [];
    commands.forEach((key, value) {
      parts.add('$key=$value');
    });

    String payload = parts.join('&');

    if (_activeType == ConnectionType.wifi && _wsChannel != null) {
      _wsChannel!.sink.add(payload);
    } else if (_activeType == ConnectionType.bluetooth &&
        _btConnection != null) {
      _btConnection!.output.add(utf8.encode('$payload\n'));
    }
  }

  void _parseIncomingData(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        // 2. Update the existing state in-place with whatever keys are present
        _currentMixerState.updateFromJson(decoded);

        // 3. Push the updated state object to the stream to trigger UI rebuilds
        _stateController.add(_currentMixerState);
      }
    } catch (_) {
      // Ignore framing or parse errors
    }
  }

  Future<void> disconnect() async {
    dev.log(
      "Disconnecting current connection.\n"
      "\t_isConnected=$_isConnected;\n"
      "\t_activeType=$_activeType;",
    );

    _demoTimer?.cancel();
    _demoTimer = null;

    await _wsChannel?.sink.close();
    await _btConnection?.close();
    udpService?.stopListening();

    _wsChannel = null;
    _btConnection = null;
    _isConnected = false;
    _activeType = null;
    notifyListeners();
  }

  Future<void> reconnect() async {
    dev.log(
      "Reconnecting current connection.\n"
      "\t_lastConnectionType=$_lastConnectionType;\n"
      "\t_isConnected=$_isConnected;\n"
      "\t_activeType=$_activeType;",
    );
    if (_lastConnectionType == ConnectionType.wifi && _lastIpAddress != null) {
      await connectWifi(_lastIpAddress!);
    } else if (_lastConnectionType == ConnectionType.bluetooth &&
        _lastBtAddress != null) {
      await connectBluetooth(_lastBtAddress!);
    } else if (_lastConnectionType == ConnectionType.demo) {
      await connectDemo();
    } else {
      throw Exception("No previous connection data to restore");
    }
  }
}

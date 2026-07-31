import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/mixer_state.dart';

enum ConnectionType { wifi, bluetooth }

class Esp32ConnectionService extends ChangeNotifier {
  String? _lastIpAddress;
  String? _lastBtAddress;
  ConnectionType? _lastConnectionType;

  ConnectionType? _activeType;
  bool _isConnected = false;

  WebSocketChannel? _wsChannel;
  BluetoothConnection? _btConnection;

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
        onError: (err) {
          dev.log("Error while listening to websocket: $err");
          disconnect();
        },
        onDone: () {
          dev.log("Websocket stream is done.");
          disconnect();
        },
      );

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

      _btConnection!.input?.listen((Uint8List data) {
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
      }, onDone: () => disconnect());
    } catch (e) {
      dev.log("Failed to connect to Bluetooth device: $address.");
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // SEND COMMAND FORMATTER: "speaker.mute=t&speaker.volume=0"
  // ---------------------------------------------------------------------------
  void sendCommands(Map<String, String> commands) {
    if (!_isConnected) return;

    _currentMixerState.updateFromCommands(commands);
    _stateController.add(_currentMixerState);

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
    await _wsChannel?.sink.close();
    await _btConnection?.close();
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
    } else {
      throw Exception("No previous connection data to restore");
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
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

  bool get isConnected => _isConnected;
  ConnectionType? get activeType => _activeType;

  // ---------------------------------------------------------------------------
  // CONNECT VIA WI-FI (WebSocket)
  // ---------------------------------------------------------------------------
  Future<void> connectWifi(String ipAddress) async {
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
        onError: (err) => disconnect(),
        onDone: () => disconnect(),
      );

      _activeType = ConnectionType.wifi;
      _isConnected = true;
      notifyListeners();

    } catch (e) {
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

    List<String> parts = [];
    commands.forEach((key, value) {
      parts.add('$key=$value');
    });

    String payload = parts.join('&');

    if (_activeType == ConnectionType.wifi && _wsChannel != null) {
      _wsChannel!.sink.add(payload);
    } else if (_activeType == ConnectionType.bluetooth && _btConnection != null) {
      _btConnection!.output.add(utf8.encode('$payload\n'));
    }
  }

  void _parseIncomingData(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        _stateController.add(MixerState.fromJson(decoded));
      }
    } catch (_) {
      // Ignore framing or parse errors
    }
  }

  Future<void> disconnect() async {
    await _wsChannel?.sink.close();
    await _btConnection?.close();
    _wsChannel = null;
    _btConnection = null;
    _isConnected = false;
    _activeType = null;
    notifyListeners();
  }

  Future<void> reconnect() async {
    if (_lastConnectionType == ConnectionType.wifi && _lastIpAddress != null) {
      await connectWifi(_lastIpAddress!);
    } else if (_lastConnectionType == ConnectionType.bluetooth && _lastBtAddress != null) {
      await connectBluetooth(_lastBtAddress!);
    } else {
      throw Exception("No previous connection data to restore");
    }
  }
}
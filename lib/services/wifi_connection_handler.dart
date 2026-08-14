import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ping_service.dart';
import 'udp_meter_service.dart';

class WifiConnectionHandler {
  final String ipAddress;
  final PingService pingService;

  // Callbacks for data routing back to the main service
  final void Function(Map<String, dynamic> json) onJsonData;
  final void Function(double peak, double avg, List<double> spectrum)
  onMeterData;
  final void Function() onDisconnected;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  UdpMeterService? _udpService;

  bool _isDisconnecting = false;

  WifiConnectionHandler({
    required this.ipAddress,
    required this.pingService,
    required this.onJsonData,
    required this.onMeterData,
    required this.onDisconnected,
  });

  Future<void> connect() async {
    final wsUrl = 'ws://$ipAddress/ws';

    // 1. Establish the WebSocket connection
    final ws = await WebSocket.connect(wsUrl).timeout(
      const Duration(seconds: 5),
      onTimeout: () =>
          throw TimeoutException('Connection timed out. Device unreachable.'),
    );

    ws.pingInterval = const Duration(seconds: 3);
    _wsChannel = IOWebSocketChannel(ws);

    // Listen to WebSocket events
    _wsSubscription = _wsChannel!.stream.listen(
      (data) => _parseIncomingData(data.toString()),
      onError: (error) {
        dev.log("Error while listening to websocket: $error", error: error);
        _triggerDisconnectEvent();
      },
      onDone: () {
        dev.log("Websocket stream is done.");
        _triggerDisconnectEvent();
      },
      cancelOnError: true,
    );

    // 2. Establish the high-speed UDP connection
    _udpService = UdpMeterService();
    _udpService!.onMeterData = onMeterData;
    _udpService!.startListening(5005);

    // 3. Start UI Ping tracking
    pingService.start(_wsChannel!);
  }

  void sendPayload(String payload) {
    _wsChannel?.sink.add(payload);
  }

  void _parseIncomingData(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('pong')) {
          pingService.handleIncomingJson(decoded);
        } else {
          onJsonData(decoded);
        }
      }
    } catch (_) {}
  }

  Future<void> disconnect() async {
    if (_isDisconnecting) return;
    _isDisconnecting = true;

    pingService.stop();

    await _wsSubscription?.cancel();
    _wsSubscription = null;

    await _wsChannel?.sink.close();
    _wsChannel = null;

    _udpService?.stopListening();
    _udpService = null;
  }

  Future<void> _triggerDisconnectEvent() async {
    await disconnect();
    onDisconnected();
  }
}

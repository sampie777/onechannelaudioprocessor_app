import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class PingService extends ChangeNotifier {
  Timer? _pingTimer;
  int _pingMs = 0;

  /// Current round-trip time in milliseconds
  int get pingMs => _pingMs;

  set pingMs(int value) {
    _pingMs = value;
    notifyListeners();
  }

  /// Starts the ping loop sending `ping=<timestamp>` every 2 seconds
  void start(WebSocketChannel channel) {
    stop();

    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final int now = DateTime.now().millisecondsSinceEpoch;

      try {
        channel.sink.add('ping=$now');
      } catch (_) {}
    });
  }

  /// Parses incoming JSON payloads for `pong` responses
  void handleIncomingJson(Map<String, dynamic> json) {
    if (!json.containsKey('pong')) return;

    final dynamic ts = json['pong'];
    final int? sentTimestamp = ts is int ? ts : int.tryParse(ts.toString());

    if (sentTimestamp == null) return;

    final int now = DateTime.now().millisecondsSinceEpoch;
    _pingMs = (now - sentTimestamp).clamp(0, 9999);
    notifyListeners();
  }

  /// Stops the ping loop and resets latency
  void stop() {
    _pingTimer?.cancel();
    _pingTimer = null;
    if (_pingMs == 0) return;

    _pingMs = 0;
    notifyListeners();
  }
}

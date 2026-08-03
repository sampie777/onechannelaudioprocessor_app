import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

class UdpMeterService {
  RawDatagramSocket? _socket;

  // Callbacks for incoming meter updates
  Function(double peak, double avg)? onMeterData;

  Future<void> startListening(int port) async {
    stopListening();

    try {
      dev.log("Connecting to UDP address on $port...");
      // Bind to any incoming IPv4 address on the port
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _socket?.receive();
          if (dg != null && dg.data.length >= 8) {
            _parseBinaryPayload(dg.data);
          }
        }
      });
    } catch (e) {
      dev.log("UDP Socket error: $e", error: e);
    }
  }

  void _parseBinaryPayload(Uint8List data) {
    // Parse two 32-bit float values directly from the binary buffer
    final byteData = ByteData.sublistView(data);
    final double peak = byteData.getFloat32(0, Endian.little);
    final double avg = byteData.getFloat32(4, Endian.little);

    if (onMeterData != null) {
      onMeterData!(peak, avg);
    }
  }

  void stopListening() {
    _socket?.close();
    _socket = null;
  }
}
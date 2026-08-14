import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

class UdpMeterService {
  RawDatagramSocket? _socket;

  // Callbacks for incoming meter updates
  Function(double peak, double avg, List<double> spectrum)? onMeterData;

  Future<void> startListening(int port) async {
    stopListening();

    try {
      dev.log("Connecting to UDP address on $port...");
      // Bind to any incoming IPv4 address on the port
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _socket?.receive();
          // The payload is 2 floats (8 bytes) + 32 floats (128 bytes) = 136 bytes
          if (dg != null && dg.data.length >= 136) {
            _parseBinaryPayload(dg.data);
          }
        }
      });
    } catch (e) {
      dev.log("UDP Socket error: $e", error: e);
    }
  }

  void _parseBinaryPayload(Uint8List data) {
    final byteData = ByteData.sublistView(data);
    final double peak = byteData.getFloat32(0, Endian.little);
    final double avg = byteData.getFloat32(4, Endian.little);

    // Parse the 32 spectrum bins
    final List<double> spectrum = List.filled(32, 0.0);
    for (int i = 0; i < 32; i++) {
      spectrum[i] = byteData.getFloat32(8 + (i * 4), Endian.little);
    }

    if (onMeterData != null) {
      onMeterData!(peak, avg, spectrum);
    }
  }

  void stopListening() {
    dev.log("Closing UDP connection");
    _socket?.close();
    _socket = null;
  }
}
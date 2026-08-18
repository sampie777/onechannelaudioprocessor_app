import 'dart:async';

import 'package:flutter/services.dart';

class HardwareVolumeService {
  static final HardwareVolumeService _instance =
      HardwareVolumeService._internal();

  factory HardwareVolumeService() => _instance;

  HardwareVolumeService._internal();

  static const EventChannel _volumeEventChannel = EventChannel(
    'nl.sajansen.onechannelaudioprocessor/volume_keys',
  );
  static const MethodChannel _volumeMethodChannel = MethodChannel(
    'nl.sajansen.onechannelaudioprocessor/volume_control',
  );

  StreamSubscription? _nativeEventSub;

  final _volumeButtonStreamController = StreamController<bool>.broadcast();

  Stream<bool> get onVolumeButtonPressed =>
      _volumeButtonStreamController.stream;

  bool _isInitialized = false;

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    _nativeEventSub = _volumeEventChannel.receiveBroadcastStream().listen((
      event,
    ) {
      if (event == "UP") {
        _volumeButtonStreamController.add(true);
      } else if (event == "DOWN") {
        _volumeButtonStreamController.add(false);
      }
    }, onError: (_) {});
  }

  /// Toggles whether Android blocks the OS popup and sends events to Flutter
  Future<void> setIntercept(bool intercept) async {
    try {
      await _volumeMethodChannel.invokeMethod('setIntercept', intercept);
    } catch (_) {}
  }

  void dispose() {
    setIntercept(false);
    _nativeEventSub?.cancel();
    _volumeButtonStreamController.close();
  }
}

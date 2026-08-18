import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../services/hardware_volume_service.dart';
import '../utils/volume_utils.dart';
import 'volume_popup_overlay.dart';

class HardwareVolumeListenerWidget extends StatefulWidget {
  final Widget child;
  final Esp32ConnectionService service;
  final bool showVolumePopup;

  /// Determines which value to update. If null, it defaults to state.dac.volume
  final Lockable? targetVolumeProperty;

  final List<double> scaleTicks;

  const HardwareVolumeListenerWidget({
    super.key,
    required this.child,
    required this.service,
    this.targetVolumeProperty,
    this.scaleTicks = const [-127.0, -80.0, -40.0, -20.0, -10.0, -5.0, 0.0],
    this.showVolumePopup = true,
  });

  @override
  State<HardwareVolumeListenerWidget> createState() =>
      _HardwareVolumeListenerWidgetState();
}

class _HardwareVolumeListenerWidgetState
    extends State<HardwareVolumeListenerWidget> with RouteAware {
  StreamSubscription<bool>? _hwVolSub;
  StreamSubscription<MixerState>? _stateSub;
  MixerState? _currentState;

  bool _showVolumePopup = false;
  Timer? _volumePopupTimer;

  @override
  void initState() {
    super.initState();

    // 1. Initialize native event channel
    HardwareVolumeService().init();

    // 2. Immediately enable hardware volume interception on mount
    HardwareVolumeService().setIntercept(true);

    _hwVolSub = HardwareVolumeService().onVolumeButtonPressed.listen((isUp) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      _handleHardwareVolume(isUp);
    });

    _stateSub = widget.service.stateStream.listen((state) {
      if (mounted) _currentState = state;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    HardwareVolumeService().setIntercept(true);
  }

  @override
  void didPopNext() {
    HardwareVolumeService().setIntercept(true);
  }

  @override
  void didPushNext() {
    HardwareVolumeService().setIntercept(false);
  }

  @override
  void didPop() {
    HardwareVolumeService().setIntercept(false);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _hwVolSub?.cancel();
    _stateSub?.cancel();
    _volumePopupTimer?.cancel();
    HardwareVolumeService().setIntercept(false);
    super.dispose();
  }

  void _handleHardwareVolume(bool isUp) {
    if (_currentState == null) return;

    final targetProperty =
        widget.targetVolumeProperty ?? _currentState!.dac.volume;
    double current = targetProperty.value.toDouble();

    double newVal;
    if (!isUp && current <= -80.0) {
      newVal = -127.0;
    } else if (isUp && current <= -127.0) {
      newVal = -80.0;
    } else {
      newVal = calculateNextVolumeStep(current, isUp);
    }

    newVal = newVal.clamp(widget.scaleTicks.first, widget.scaleTicks.last);

    widget.service.sendCommands({
      targetProperty.command: newVal.toString(),
    });

    setState(() => _showVolumePopup = true);
    _volumePopupTimer?.cancel();
    _volumePopupTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showVolumePopup = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double volValue = widget.targetVolumeProperty?.value.toDouble() ??
        (_currentState?.dac.volume.value.toDouble() ?? 0.0);

    return Stack(
      children: [
        widget.child,

        VolumePopupOverlay(
          isVisible: widget.showVolumePopup && _showVolumePopup,
          volumeDb: volValue,
          scaleTicks: widget.scaleTicks,
        ),
      ],
    );
  }
}
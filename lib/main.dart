import 'package:flutter/material.dart';

import 'screens/connection_screen.dart';
import 'services/esp32_connection_service.dart';

void main() {
  runApp(const MiniMixerApp());
}

class MiniMixerApp extends StatelessWidget {
  const MiniMixerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionService = Esp32ConnectionService();

    return MaterialApp(
      title: 'MiniMixer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
      ),
      home: ConnectionScreen(service: connectionService),
    );
  }
}
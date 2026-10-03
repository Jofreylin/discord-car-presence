import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/vehicle_provider.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsService();
  final autoDetectAndroid = await settings.readAutoDetectAndroid();
  final autoDetectCarPlay = await settings.readAutoDetectCarPlay();
  runApp(
    ChangeNotifierProvider(
      create: (_) => VehicleProvider(
        autoDetectAndroid: autoDetectAndroid,
        autoDetectCarPlay: autoDetectCarPlay,
      ),
      child: CarPresenceApp(settings: settings),
    ),
  );
}

class CarPresenceApp extends StatelessWidget {
  const CarPresenceApp({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomeScreen(settings: settings));
  }
}

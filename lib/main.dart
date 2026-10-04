import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/vehicle_provider.dart';
import 'screens/home_screen.dart';
import 'services/discord_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const applicationId = String.fromEnvironment('DISCORD_APPLICATION_ID');
  if (applicationId.isEmpty) {
    throw StateError('DISCORD_APPLICATION_ID is required');
  }
  final settings = SettingsService();
  final discord = DiscordService(
    settings: settings,
    applicationId: applicationId,
  );
  await discord.start();
  final autoDetectAndroid = await settings.readAutoDetectAndroid();
  final autoDetectCarPlay = await settings.readAutoDetectCarPlay();
  runApp(
    ChangeNotifierProvider(
      create: (_) => VehicleProvider(
        autoDetectAndroid: autoDetectAndroid,
        autoDetectCarPlay: autoDetectCarPlay,
        discord: discord,
      ),
      child: CarPresenceApp(settings: settings, discord: discord),
    ),
  );
}

class CarPresenceApp extends StatelessWidget {
  const CarPresenceApp({
    super.key,
    required this.settings,
    required this.discord,
  });

  final SettingsService settings;
  final DiscordService discord;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(settings: settings, discord: discord),
    );
  }
}

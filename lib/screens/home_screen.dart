import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/connection_type.dart';
import '../providers/vehicle_provider.dart';
import '../services/discord_service.dart';
import '../services/settings_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.discord,
  });

  final SettingsService settings;
  final DiscordService discord;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VehicleProvider>();
    final state = provider.state;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!state.carMode) ...[
                const _OffHeader(),
                const SizedBox(height: 32),
                _DiscordSection(discord: discord),
                const SizedBox(height: 32),
                const Text('Estado del vehículo'),
                const SizedBox(height: 8),
                const Text('No conectado', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const _ActivateButton(),
              ] else ...[
                _ActiveSession(connectionType: state.connectionType),
                const SizedBox(height: 32),
                _DiscordSection(discord: discord),
              ],
              const SizedBox(height: 32),
              Text('Detección automática'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Android Auto'),
                value: provider.autoDetectAndroid,
                onChanged: (value) => _setAndroid(context, value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Apple CarPlay'),
                value: provider.autoDetectCarPlay,
                onChanged: (value) => _setCarPlay(context, value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setAndroid(BuildContext context, bool value) async {
    await settings.writeAutoDetectAndroid(value);
    if (!context.mounted) {
      return;
    }
    context.read<VehicleProvider>().setAutoDetectAndroid(value);
  }

  Future<void> _setCarPlay(BuildContext context, bool value) async {
    await settings.writeAutoDetectCarPlay(value);
    if (!context.mounted) {
      return;
    }
    context.read<VehicleProvider>().setAutoDetectCarPlay(value);
  }
}

class _OffHeader extends StatelessWidget {
  const _OffHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🚗', style: TextStyle(fontSize: 28)),
        SizedBox(width: 8),
        Text('CAR PRESENCE', style: TextStyle(fontSize: 28)),
      ],
    );
  }
}

class _DiscordSection extends StatelessWidget {
  const _DiscordSection({required this.discord});

  final DiscordService discord;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: discord,
      builder: (context, _) {
        final name = discord.displayName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Discord'),
            const SizedBox(height: 8),
            if (name == null) ...[
              const Text('Cuenta sin conectar'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  unawaited(discord.connect());
                },
                child: const Text('Conectar Discord'),
              ),
            ] else ...[
              Text(name),
              const SizedBox(height: 8),
              const Text('Cuenta conectada'),
              TextButton(
                onPressed: () {
                  unawaited(discord.disconnect());
                },
                child: const Text('Cerrar sesión'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ActivateButton extends StatelessWidget {
  const _ActivateButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => context.read<VehicleProvider>().setManualLatched(true),
      child: const Text('ACTIVAR MODO CARRO'),
    );
  }
}

class _ActiveSession extends StatelessWidget {
  const _ActiveSession({required this.connectionType});

  final CarConnectionType connectionType;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('🚗', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        const Text(
          'MODO CARRO ACTIVO',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
        const SizedBox(height: 8),
        Text(_subtitle(connectionType), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const _SessionClock(),
        const SizedBox(height: 16),
        if (connectionType == CarConnectionType.manual)
          FilledButton(
            onPressed: () =>
                context.read<VehicleProvider>().setManualLatched(false),
            child: const Text('FINALIZAR MODO CARRO'),
          )
        else
          const _ActivateButton(),
      ],
    );
  }
}

class _SessionClock extends StatefulWidget {
  const _SessionClock();

  @override
  State<_SessionClock> createState() => _SessionClockState();
}

class _SessionClockState extends State<_SessionClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = context.watch<VehicleProvider>().state.connectedSince;
    if (since == null) {
      return const SizedBox.shrink();
    }
    final elapsed = DateTime.now().difference(since);
    final shown = elapsed.isNegative ? Duration.zero : elapsed;
    return Text(formatCarSession(shown));
  }
}

String formatCarSession(Duration elapsed) {
  final hours = elapsed.inHours.toString().padLeft(2, '0');
  final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _subtitle(CarConnectionType connectionType) {
  switch (connectionType) {
    case CarConnectionType.manual:
      return 'Activado manualmente';
    case CarConnectionType.androidAuto:
      return 'Detectado por Android Auto';
    case CarConnectionType.carPlay:
      return 'Detectado por Apple CarPlay';
    case CarConnectionType.none:
      return '';
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/connection_type.dart';
import '../models/vehicle_state.dart';
import '../services/discord_service.dart';

class VehicleProvider extends ChangeNotifier {
  VehicleProvider({
    DateTime Function()? clock,
    bool autoDetectAndroid = true,
    bool autoDetectCarPlay = true,
    DiscordService? discord,
  }) : _clock = clock ?? DateTime.now {
    _autoDetectAndroid = autoDetectAndroid;
    _autoDetectCarPlay = autoDetectCarPlay;
    _discord = discord;
  }

  final DateTime Function() _clock;
  DiscordService? _discord;

  bool _manualLatched = false;
  bool _androidAutoConnected = false;
  bool _carPlayConnected = false;
  bool _autoDetectAndroid = true;
  bool _autoDetectCarPlay = true;

  VehicleState _state = const VehicleState(
    carMode: false,
    connectionType: CarConnectionType.none,
    connectedSince: null,
  );

  VehicleState get state => _state;

  bool get autoDetectAndroid => _autoDetectAndroid;

  bool get autoDetectCarPlay => _autoDetectCarPlay;

  void setManualLatched(bool value) {
    _manualLatched = value;
    _recompute();
  }

  void setAndroidAutoConnected(bool value) {
    _androidAutoConnected = value;
    _recompute();
  }

  void setCarPlayConnected(bool value) {
    _carPlayConnected = value;
    _recompute();
  }

  void setAutoDetectAndroid(bool value) {
    _autoDetectAndroid = value;
    _recompute();
  }

  void setAutoDetectCarPlay(bool value) {
    _autoDetectCarPlay = value;
    _recompute();
  }

  void _recompute() {
    final autoAndroidActive = _autoDetectAndroid && _androidAutoConnected;
    final autoCarPlayActive = _autoDetectCarPlay && _carPlayConnected;
    final carMode = _manualLatched || autoAndroidActive || autoCarPlayActive;

    final CarConnectionType connectionType;
    if (autoCarPlayActive) {
      connectionType = CarConnectionType.carPlay;
    } else if (autoAndroidActive) {
      connectionType = CarConnectionType.androidAuto;
    } else if (_manualLatched) {
      connectionType = CarConnectionType.manual;
    } else {
      connectionType = CarConnectionType.none;
    }

    DateTime? connectedSince;
    if (!carMode) {
      connectedSince = null;
    } else if (!_state.carMode) {
      connectedSince = _clock();
    } else {
      connectedSince = _state.connectedSince;
    }

    _state = VehicleState(
      carMode: carMode,
      connectionType: connectionType,
      connectedSince: connectedSince,
    );
    notifyListeners();
    final discord = _discord;
    if (discord != null) {
      unawaited(
        discord.applyDesired(presenceDetails(_state), presenceState(_state)),
      );
    }
  }
}

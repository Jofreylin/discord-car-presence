import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'settings_service.dart';

class DiscordService extends ChangeNotifier {
  DiscordService({
    required this.settings,
    required this.applicationId,
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('car_presence/discord');

  final SettingsService settings;
  final String applicationId;
  final MethodChannel _channel;

  String? displayName;
  String status = 'disconnected';
  String? errorMessage;

  String? _desiredDetails;
  String? _desiredState;
  bool _published = false;
  Future<void> _pending = Future<void>.value();

  Map<String, Object?> get accountView => {
    'displayName': displayName,
    'connected': displayName != null,
  };

  Future<void> start() async {
    _channel.setMethodCallHandler(_onNativeCall);
    try {
      await _channel.invokeMethod<void>('start', {
        'applicationId': applicationId,
      });
    } on MissingPluginException {
      status = 'disconnected';
      notifyListeners();
    }
  }

  Future<void> connect() async {
    errorMessage = null;
    status = 'connecting';
    notifyListeners();
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'connect',
        {'applicationId': applicationId},
      );
      final access = result?['accessToken'] as String?;
      final refresh = result?['refreshToken'] as String?;
      if (access != null && access.isNotEmpty) {
        await settings.writeDiscordAccessToken(access);
      }
      if (refresh != null && refresh.isNotEmpty) {
        await settings.writeDiscordRefreshToken(refresh);
      }
      await _enterReady();
    } catch (error) {
      displayName = null;
      status = 'error';
      errorMessage = '$error';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod<void>('disconnect');
    } catch (_) {}
    await settings.deleteDiscordTokens();
    displayName = null;
    status = 'disconnected';
    errorMessage = null;
    notifyListeners();
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'readStoredTokens':
        return _readStoredTokens();
      case 'replaceStoredTokens':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        await settings.writeDiscordAccessToken(args['accessToken'] as String);
        await settings.writeDiscordRefreshToken(args['refreshToken'] as String);
        return null;
      case 'clearStoredTokens':
        await settings.deleteDiscordTokens();
        displayName = null;
        status = 'disconnected';
        notifyListeners();
        return null;
      case 'onStatus':
        final next = call.arguments as String? ?? 'disconnected';
        if (next == 'ready') {
          await _enterReady();
          return null;
        }
        status = next;
        if (next == 'disconnected') {
          displayName = null;
        }
        notifyListeners();
        return null;
      default:
        throw PlatformException(code: 'not_implemented');
    }
  }

  Future<Map<String, String>?> _readStoredTokens() async {
    final access = await settings.readDiscordAccessToken();
    if (access == null || access.isEmpty) {
      return null;
    }
    final refresh = await settings.readDiscordRefreshToken();
    return {'accessToken': access, 'refreshToken': refresh ?? ''};
  }

  Future<void> applyDesired(String? details, String? state) {
    _desiredDetails = details;
    _desiredState = state;
    return _enqueueFlush();
  }

  Future<void> _enterReady() async {
    final wasReady = status == 'ready';
    status = 'ready';
    await _loadUser();
    if (!wasReady) {
      await _enqueueFlush();
    }
  }

  Future<void> _enqueueFlush() {
    final run = _pending.then((_) => _flushOnce());
    _pending = run.catchError((Object _) {});
    return run;
  }

  Future<void> _flushOnce() async {
    if (status != 'ready') {
      return;
    }
    final details = _desiredDetails;
    final state = _desiredState;
    if (details != null && state != null) {
      await _channel.invokeMethod<void>('updatePresence', {
        'details': details,
        'state': state,
      });
      if (_desiredDetails == details && _desiredState == state) {
        _published = true;
      }
      return;
    }
    if (_published && _desiredDetails == null && _desiredState == null) {
      await _channel.invokeMethod<void>('clearPresence');
      if (_desiredDetails == null && _desiredState == null) {
        _published = false;
      }
    }
  }

  Future<void> _loadUser() async {
    final user = await _channel.invokeMapMethod<String, dynamic>(
      'getCurrentUser',
    );
    final name = user?['displayName'] as String?;
    if (name == null || name.isEmpty) {
      displayName = null;
    } else {
      displayName = name;
      status = 'ready';
    }
    notifyListeners();
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _autoDetectAndroidKey = 'auto_detect_android';
  static const _autoDetectCarPlayKey = 'auto_detect_carplay';
  static const _accessTokenKey = 'discord_access_token';
  static const _refreshTokenKey = 'discord_refresh_token';

  final FlutterSecureStorage _secureStorage;

  static const _cacheOptions = SharedPreferencesWithCacheOptions(
    allowList: <String>{_autoDetectAndroidKey, _autoDetectCarPlayKey},
  );

  SharedPreferencesWithCache? _prefs;

  Future<SharedPreferencesWithCache> _store() async {
    return _prefs ??= await SharedPreferencesWithCache.create(
      cacheOptions: _cacheOptions,
    );
  }

  Future<bool> readAutoDetectAndroid() async {
    final prefs = await _store();
    return prefs.getBool(_autoDetectAndroidKey) ?? true;
  }

  Future<bool> readAutoDetectCarPlay() async {
    final prefs = await _store();
    return prefs.getBool(_autoDetectCarPlayKey) ?? true;
  }

  Future<void> writeAutoDetectAndroid(bool value) async {
    final prefs = await _store();
    await prefs.setBool(_autoDetectAndroidKey, value);
  }

  Future<void> writeAutoDetectCarPlay(bool value) async {
    final prefs = await _store();
    await prefs.setBool(_autoDetectCarPlayKey, value);
  }

  Future<String?> readDiscordAccessToken() {
    return _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> readDiscordRefreshToken() {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> writeDiscordAccessToken(String value) {
    return _secureStorage.write(key: _accessTokenKey, value: value);
  }

  Future<void> writeDiscordRefreshToken(String value) {
    return _secureStorage.write(key: _refreshTokenKey, value: value);
  }

  Future<void> deleteDiscordTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}

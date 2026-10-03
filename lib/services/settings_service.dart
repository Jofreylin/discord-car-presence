import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _autoDetectAndroidKey = 'auto_detect_android';
  static const _autoDetectCarPlayKey = 'auto_detect_carplay';

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
}

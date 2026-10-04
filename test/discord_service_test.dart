import 'dart:io';

import 'package:car_presence/main.dart';
import 'package:car_presence/providers/vehicle_provider.dart';
import 'package:car_presence/services/discord_service.dart';
import 'package:car_presence/services/settings_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  const channel = MethodChannel('car_presence/discord');
  const accessToken = 'access-secret';
  const refreshToken = 'refresh-secret';

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  Future<void> pumpHome(WidgetTester tester, DiscordService discord) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => VehicleProvider(),
        child: CarPresenceApp(settings: discord.settings, discord: discord),
      ),
    );
  }

  testWidgets('connect stores both tokens outside the screen', (tester) async {
    mockChannel((call) async {
      if (call.method == 'connect') {
        return {
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        };
      }
      if (call.method == 'getCurrentUser') {
        return {
          'userId': '1',
          'username': 'car_user',
          'displayName': 'Shown Name',
        };
      }
      return null;
    });
    final settings = SettingsService();
    final discord = DiscordService(settings: settings, applicationId: '1');
    await pumpHome(tester, discord);

    await tester.tap(find.text('Conectar Discord'));
    await tester.pump();
    await tester.pump();

    expect(await settings.readDiscordAccessToken(), accessToken);
    expect(await settings.readDiscordRefreshToken(), refreshToken);
    expect(find.text('Shown Name'), findsOneWidget);
    expect(find.text('Cuenta conectada'), findsOneWidget);
    expect(find.text(accessToken), findsNothing);
    expect(find.text(refreshToken), findsNothing);
    expect(discord.accountView.keys.toList(), ['displayName', 'connected']);
    expect(discord.accountView.values, isNot(contains(accessToken)));
    expect(discord.accountView.values, isNot(contains(refreshToken)));
  });

  test('disconnect clears tokens when revoke fails', () async {
    FlutterSecureStorage.setMockInitialValues({
      'discord_access_token': accessToken,
      'discord_refresh_token': refreshToken,
    });
    mockChannel((call) async {
      if (call.method == 'disconnect') {
        throw PlatformException(code: 'revoke_failed');
      }
      return null;
    });
    final settings = SettingsService();
    final discord = DiscordService(settings: settings, applicationId: '1');

    await discord.disconnect();

    expect(await settings.readDiscordAccessToken(), isNull);
    expect(await settings.readDiscordRefreshToken(), isNull);
    expect(discord.displayName, isNull);
  });

  testWidgets('null current user leaves the account disconnected', (
    tester,
  ) async {
    mockChannel((call) async {
      if (call.method == 'connect') {
        return {
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        };
      }
      if (call.method == 'getCurrentUser') {
        return null;
      }
      return null;
    });
    final settings = SettingsService();
    final discord = DiscordService(settings: settings, applicationId: '1');
    await pumpHome(tester, discord);

    await tester.tap(find.text('Conectar Discord'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Cuenta sin conectar'), findsOneWidget);
    expect(find.text('Cuenta conectada'), findsNothing);
    expect(discord.displayName, isNull);
  });

  test('HomeScreen does not call readStoredTokens', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(source.contains('readStoredTokens'), isFalse);
  });
}

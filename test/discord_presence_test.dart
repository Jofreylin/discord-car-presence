import 'dart:async';

import 'package:car_presence/main.dart';
import 'package:car_presence/providers/vehicle_provider.dart';
import 'package:car_presence/services/discord_service.dart';
import 'package:car_presence/services/settings_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  const channel = MethodChannel('car_presence/discord');
  const codec = StandardMethodCodec();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<MethodCall> mockChannel() {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getCurrentUser') {
            return {
              'userId': '1',
              'username': 'car_user',
              'displayName': 'Shown Name',
            };
          }
          return null;
        });
    return calls;
  }

  List<MethodCall> presenceCalls(List<MethodCall> calls) {
    return calls
        .where(
          (call) =>
              call.method == 'updatePresence' || call.method == 'clearPresence',
        )
        .toList();
  }

  Future<void> emitStatus(String status) async {
    final completer = Completer<ByteData?>();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(MethodCall('onStatus', status)),
          completer.complete,
        );
    await completer.future;
  }

  test(
    'manual activate while ready publishes Driving and Car Mode once',
    () async {
      final calls = mockChannel();
      final discord = DiscordService(
        settings: SettingsService(),
        applicationId: '1',
      );
      discord.status = 'ready';
      final provider = VehicleProvider(discord: discord);

      provider.setManualLatched(true);
      await pumpEventQueue();

      final presence = presenceCalls(calls);
      expect(presence, hasLength(1));
      expect(presence.single.method, 'updatePresence');
      expect(presence.single.arguments, {
        'details': 'Driving',
        'state': 'Car Mode',
      });
    },
  );

  test('finish clears presence and does not publish again', () async {
    final calls = mockChannel();
    final discord = DiscordService(
      settings: SettingsService(),
      applicationId: '1',
    );
    discord.status = 'ready';
    final provider = VehicleProvider(discord: discord);

    provider.setManualLatched(true);
    await pumpEventQueue();
    provider.setManualLatched(false);
    await pumpEventQueue();

    expect(presenceCalls(calls).map((call) => call.method), [
      'updatePresence',
      'clearPresence',
    ]);
  });

  test('activate before ready publishes once when ready arrives', () async {
    final calls = mockChannel();
    final discord = DiscordService(
      settings: SettingsService(),
      applicationId: '1',
    );
    await discord.start();
    final provider = VehicleProvider(discord: discord);

    provider.setManualLatched(true);
    await pumpEventQueue();
    expect(presenceCalls(calls), isEmpty);

    await emitStatus('ready');

    final presence = presenceCalls(calls);
    expect(presence, hasLength(1));
    expect(presence.single.arguments, {
      'details': 'Driving',
      'state': 'Car Mode',
    });
  });

  test('activate and finish before ready does not clear', () async {
    final calls = mockChannel();
    final discord = DiscordService(
      settings: SettingsService(),
      applicationId: '1',
    );
    await discord.start();
    final provider = VehicleProvider(discord: discord);

    provider.setManualLatched(true);
    provider.setManualLatched(false);
    await pumpEventQueue();
    await emitStatus('ready');

    expect(presenceCalls(calls), isEmpty);
  });

  test('disconnect leaves car mode on and a later ready publishes', () async {
    final calls = mockChannel();
    final discord = DiscordService(
      settings: SettingsService(),
      applicationId: '1',
    );
    await discord.start();
    discord.status = 'ready';
    final provider = VehicleProvider(discord: discord);

    provider.setManualLatched(true);
    await pumpEventQueue();
    await discord.disconnect();

    expect(provider.state.carMode, isTrue);
    expect(discord.status, 'disconnected');
    expect(presenceCalls(calls).map((call) => call.method), ['updatePresence']);

    await emitStatus('ready');

    expect(presenceCalls(calls).map((call) => call.method), [
      'updatePresence',
      'updatePresence',
    ]);
    expect(presenceCalls(calls).last.arguments, {
      'details': 'Driving',
      'state': 'Car Mode',
    });
  });

  testWidgets('car mode without a ready account shows the pending legend', (
    tester,
  ) async {
    final settings = SettingsService();
    final discord = DiscordService(settings: settings, applicationId: '1');
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => VehicleProvider(discord: discord),
        child: CarPresenceApp(settings: settings, discord: discord),
      ),
    );

    expect(find.text('La presencia se publicará al conectar'), findsNothing);

    await tester.tap(find.text('ACTIVAR MODO CARRO'));
    await tester.pump();

    expect(find.text('MODO CARRO ACTIVO'), findsOneWidget);
    expect(find.text('La presencia se publicará al conectar'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

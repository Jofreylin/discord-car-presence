import 'package:car_presence/main.dart';
import 'package:car_presence/providers/vehicle_provider.dart';
import 'package:car_presence/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester,
    VehicleProvider provider,
    SettingsService settings,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => provider,
        child: CarPresenceApp(settings: settings),
      ),
    );
  }

  SwitchListTile switchTile(WidgetTester tester, String title) {
    return tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, title),
    );
  }

  testWidgets('starts disconnected with both switches on', (tester) async {
    await pumpHome(tester, VehicleProvider(), SettingsService());

    expect(find.text('Cuenta sin conectar'), findsOneWidget);
    expect(find.text('No conectado'), findsOneWidget);
    expect(find.text('ACTIVAR MODO CARRO'), findsOneWidget);
    expect(switchTile(tester, 'Android Auto').value, isTrue);
    expect(switchTile(tester, 'Apple CarPlay').value, isTrue);
    expect(find.text('FINALIZAR MODO CARRO'), findsNothing);
  });

  testWidgets('activate and finish manual mode', (tester) async {
    await pumpHome(tester, VehicleProvider(), SettingsService());

    await tester.tap(find.text('ACTIVAR MODO CARRO'));
    await tester.pump();

    expect(find.text('MODO CARRO ACTIVO'), findsOneWidget);
    expect(find.text('Activado manualmente'), findsOneWidget);
    expect(find.text('FINALIZAR MODO CARRO'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d{2}:\d{2}:\d{2}')), findsOneWidget);

    await tester.tap(find.text('FINALIZAR MODO CARRO'));
    await tester.pump();

    expect(find.text('No conectado'), findsOneWidget);
    expect(find.text('FINALIZAR MODO CARRO'), findsNothing);
  });

  testWidgets('android auto hides the finish button', (tester) async {
    final provider = VehicleProvider();
    provider.setAndroidAutoConnected(true);

    await pumpHome(tester, provider, SettingsService());

    expect(find.text('Detectado por Android Auto'), findsOneWidget);
    expect(find.text('FINALIZAR MODO CARRO'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('connect discord does nothing', (tester) async {
    await pumpHome(tester, VehicleProvider(), SettingsService());

    await tester.tap(find.text('Conectar Discord'));
    await tester.pump();

    expect(find.text('Cuenta sin conectar'), findsOneWidget);
  });

  testWidgets('turning android auto off stores the key and leaves the car off', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final settings = SettingsService();

    expect(await settings.readAutoDetectAndroid(), isTrue);
    expect(await settings.readAutoDetectCarPlay(), isTrue);

    await pumpHome(tester, VehicleProvider(), settings);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Android Auto'));
    await tester.pump();

    expect(await settings.readAutoDetectAndroid(), isFalse);
    expect(switchTile(tester, 'Android Auto').value, isFalse);
    expect(find.text('No conectado'), findsOneWidget);
    expect(find.text('MODO CARRO ACTIVO'), findsNothing);
  });
}

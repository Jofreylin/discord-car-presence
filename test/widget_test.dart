import 'package:car_presence/main.dart';
import 'package:car_presence/providers/vehicle_provider.dart';
import 'package:car_presence/services/discord_service.dart';
import 'package:car_presence/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows CAR PRESENCE', (WidgetTester tester) async {
    final settings = SettingsService();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => VehicleProvider(),
        child: CarPresenceApp(
          settings: settings,
          discord: DiscordService(settings: settings, applicationId: '1'),
        ),
      ),
    );

    expect(find.text('CAR PRESENCE'), findsOneWidget);
  });
}

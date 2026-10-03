import 'package:car_presence/main.dart';
import 'package:car_presence/providers/vehicle_provider.dart';
import 'package:car_presence/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows CAR PRESENCE', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => VehicleProvider(),
        child: CarPresenceApp(settings: SettingsService()),
      ),
    );

    expect(find.text('CAR PRESENCE'), findsOneWidget);
  });
}

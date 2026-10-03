import 'package:flutter_test/flutter_test.dart';

import 'package:car_presence/main.dart';

void main() {
  testWidgets('shows CAR PRESENCE', (WidgetTester tester) async {
    await tester.pumpWidget(const CarPresenceApp());

    expect(find.text('CAR PRESENCE'), findsOneWidget);
  });
}

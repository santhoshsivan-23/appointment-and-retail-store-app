import 'package:flutter_test/flutter_test.dart';
import 'package:appointment_and_hotel_booking/main.dart';

void main() {
  testWidgets('App smoke test loads LoginScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Sign In to Terminal'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_tracker/main.dart';

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(firebaseInitialization: Future.value()));
    await tester.pump();

    expect(find.text('Fridge Tracker'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Adgangskode'), findsOneWidget);
    expect(find.text('Log ind'), findsOneWidget);
  });
}

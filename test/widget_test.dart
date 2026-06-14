import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_tracker/main.dart';

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        firebaseInitialization: Future.value(),
        authStateChanges: Stream.value(null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fridge Tracker'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Adgangskode'), findsOneWidget);
    expect(find.text('Log ind'), findsOneWidget);
  });

  testWidgets('validates login form before calling Firebase', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        firebaseInitialization: Future.value(),
        authStateChanges: Stream.value(null),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log ind'));
    await tester.pump();

    expect(find.text('Ugyldig emailadresse'), findsOneWidget);
    expect(
      find.text('Adgangskoden skal v\u00e6re mindst 6 tegn'),
      findsOneWidget,
    );
  });
}

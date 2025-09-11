
import 'package:flutter_test/flutter_test.dart';

import 'package:waltid/main.dart';
import 'package:waltid/views/credential_view.dart';

void main() {
  testWidgets('App shows LoginView when not logged in', (WidgetTester tester) async {
    // Build our app with isLoggedIn = false
    await tester.pumpWidget(const MyApp(isLoggedIn: false));

    // Now you can verify that LoginView widgets are present.
    // For example, check that the "Sign in" title is rendered:
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // If you still want to run the old counter test, emulate a logged-in state:
    await tester.pumpWidget(const MyApp(isLoggedIn: true));

    // Then find whatever your home screen shows (you’ll need to adapt these
    // if your home screen no longer has a counter).
    // For a quick placeholder:
    expect(find.byType(CredentialView), findsOneWidget);
  });
}

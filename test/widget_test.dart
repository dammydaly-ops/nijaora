import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nijagig/app/app.dart';
import 'package:nijagig/data/models/app_user.dart';
import 'package:nijagig/data/repositories/providers.dart';
import 'package:nijagig/features/auth/presentation/onboarding_screen.dart';
import 'package:nijagig/features/auth/presentation/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('signed-out customers land on the sign-in screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding.seen': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(null)),
        ],
        child: const NijaoraApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Full name'), findsNothing);
    expect(find.textContaining('Demo code'), findsNothing);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Create a password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.textContaining('Demo code'), findsNothing);
  });

  testWidgets('first launch shows onboarding after the splash', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(null)),
        ],
        child: const NijaoraApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Find your inner light.'), findsOneWidget);
  });

  testWidgets('guests can browse without signing in', (tester) async {
    SharedPreferences.setMockInitialValues({
      'guest.mode': true,
      'onboarding.seen': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(null)),
        ],
        child: const NijaoraApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    // Let the demo repository's simulated network delays complete.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    // The home hero has intentional, continuous ambient motion, so this test
    // advances a fixed frame instead of waiting for the tree to settle.
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(WelcomeScreen), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });
}

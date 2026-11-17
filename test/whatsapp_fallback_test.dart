import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nijagig/app/theme/app_theme.dart';
import 'package:nijagig/data/models/app_user.dart';
import 'package:nijagig/data/repositories/providers.dart';
import 'package:nijagig/features/business/presentation/business_profile_screen.dart';
import 'package:nijagig/features/chat/presentation/chat_thread_screen.dart';
import 'package:nijagig/features/products/presentation/product_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final user = AppUser(
    id: 'demo-customer',
    phone: '+2348031234567',
    displayName: 'Demo Customer',
    role: UserRole.customer,
    createdAt: DateTime(2026),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(
          (ref) => Stream<AppUser?>.value(user),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('business profile shows in-app chat and WhatsApp fallback', (
    tester,
  ) async {
    await _pump(
      tester,
      const BusinessProfileScreen(businessId: 'radiance-tailors'),
    );

    expect(find.text('Chat in app'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('product page shows WhatsApp seller', (tester) async {
    await _pump(
      tester,
      const ProductDetailScreen(
        businessId: 'radiance-tailors',
        listingId: 'radiance-jacket',
      ),
    );

    await tester.scrollUntilVisible(
      find.text('WhatsApp seller'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('WhatsApp seller'), findsOneWidget);
  });

  testWidgets('chat thread exposes continue on WhatsApp', (tester) async {
    await _pump(
      tester,
      const ChatThreadScreen(conversationId: 'conv-radiance'),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Continue on WhatsApp'), findsOneWidget);
  });
}

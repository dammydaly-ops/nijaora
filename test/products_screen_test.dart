import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nijagig/data/repositories/providers.dart';
import 'package:nijagig/features/products/presentation/products_screen.dart';

void main() {
  test('demo products cover fashion, home and food', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final items = await container.read(productItemsProvider.future);
    final categoryIds = items
        .map((item) => item.category?.id)
        .whereType<String>()
        .toSet();

    expect(items.length, greaterThanOrEqualTo(25));
    expect(categoryIds, contains('product-clothing'));
    expect(categoryIds, contains('product-furniture'));
    expect(categoryIds, contains('product-food'));
    expect(categoryIds, contains('product-skincare'));
  });

  testWidgets('products tab lists ready-made items', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProductsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Ankara midi dress'), findsOneWidget);
    expect(find.textContaining('products'), findsWidgets);
  });
}

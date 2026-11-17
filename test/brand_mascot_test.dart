import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nijagig/app/theme/app_theme.dart';
import 'package:nijagig/core/widgets/brand_mascot.dart';

void main() {
  testWidgets('uses the same white/green mascot in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: Center(child: BrandMascot())),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/mascot_light.png',
    );
  });
}

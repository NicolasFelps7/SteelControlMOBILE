import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelcontrol_mobile/app.dart';
import 'package:steelcontrol_mobile/core/app_strings.dart';
import 'package:steelcontrol_mobile/state/app_controller.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1280, 800),
    const Size(844, 390),
  ]) {
    testWidgets('login responsivo em $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(SteelControlApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        find.text(AppStrings(AppLanguage.pt).get('accessCompany')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('login traduz os campos e título nos seis idiomas', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    for (final language in AppLanguage.values) {
      controller.language = language;
      await tester.pumpWidget(
        SteelControlApp(key: ValueKey(language), controller: controller),
      );
      await tester.pumpAndSettle();
      final strings = AppStrings(language);
      expect(find.text(strings.get('email')), findsOneWidget);
      expect(find.text(strings.get('accessCompany')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

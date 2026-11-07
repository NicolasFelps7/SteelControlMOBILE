import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelcontrol_mobile/state/app_controller.dart';
import 'package:steelcontrol_mobile/screens/operation_center_screen.dart';
import 'package:steelcontrol_mobile/widgets/machine_model_3d.dart';

void main() {
  for (final size in [
    const Size(1280, 900),
    const Size(800, 1100),
    const Size(390, 844),
  ]) {
    testWidgets('supervisão técnica: retorno e cenário sem produção em $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController();
      addTearDown(controller.dispose);
      var returned = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationCenterScreen(
              controller: controller,
              onMachines: () => returned = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Voltar para Máquinas'), findsOneWidget);
      expect(find.byType(MachineModel3D), findsOneWidget);
      expect(find.text('Auditoria geral'), findsNothing);
      expect(find.text('Minha empresa'), findsOneWidget);
      expect(find.text('Manutenção'), findsOneWidget);
      expect(find.text('Produção'), findsNothing);
      await tester.tap(find.text('Voltar para Máquinas'));
      expect(returned, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

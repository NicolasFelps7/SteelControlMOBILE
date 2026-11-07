import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'machine_dashboard_screen.dart';

Future<void> showMachineControlDialog(
  BuildContext context,
  AppController controller, {
  bool automatic = false,
}) async {
  final id = controller.selectedMachine?.id;
  if (id == null) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 1100,
        height: MediaQuery.sizeOf(dialogContext).height * .88,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final machine = controller.selectedMachine;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CONTROLE · MANUAL / AUTOMÁTICO',
                              style: TextStyle(fontSize: 10),
                            ),
                            Text(
                              machine?.name ?? 'Equipamento indisponível',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              controller.session?.user.name ??
                                  'Conta autenticada',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar controle',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: machine == null || machine.id != id
                      ? const Center(
                          child: Text(
                            'Equipamento removido ou acesso encerrado.',
                          ),
                        )
                      : MachineControlSection(
                          key: ValueKey('control-$id-$automatic'),
                          controller: controller,
                          machine: machine,
                          initialAutomatic: automatic,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

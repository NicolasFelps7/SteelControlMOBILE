import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/machine_profile_panel.dart';

import '../models/machine.dart';
import '../state/app_controller.dart';
import '../widgets/machine_model_3d.dart';
import 'machine_dashboard_screen.dart';
import 'machine_control_dialog.dart';
import 'machine_connection_screen.dart';

Map<String, dynamic> machineSceneData(Machine m) {
  final dobot = m.extraData['dobot'];
  return {
    'id': m.id,
    'nome': m.name,
    'tipo': m.type,
    'modelo': m.model,
    'controlador': m.controller,
    'online': m.hasRecentTelemetry,
    'simulacao': m.simulation,
    if (dobot is Map && dobot['joints'] is Map) 'joints': dobot['joints'],
  };
}

class MachineWorkspaceScreen extends StatefulWidget {
  const MachineWorkspaceScreen({
    required this.controller,
    required this.machineId,
    this.initialTab = 0,
    super.key,
  });
  final AppController controller;
  final int machineId;
  final int initialTab;
  @override
  State<MachineWorkspaceScreen> createState() => _MachineWorkspaceScreenState();
}

class _MachineWorkspaceScreenState extends State<MachineWorkspaceScreen>
    with WidgetsBindingObserver {
  late int machineId;
  bool switching = false, polling = false, paused = false;
  Timer? refresh;
  AppController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    machineId = widget.machineId;
    WidgetsBinding.instance.addObserver(this);
    refresh = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted ||
          polling ||
          paused ||
          switching ||
          controller.selectedMachine?.id != machineId)
        return;
      polling = true;
      try {
        await controller.refreshSelectedMachine();
      } catch (_) {
      } finally {
        polling = false;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    paused = state != AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> changeMachine(int id) async {
    final next = controller.machines.where((m) => m.id == id).firstOrNull;
    if (next == null || switching) return;
    setState(() => switching = true);
    try {
      await controller.selectMachine(next);
      if (mounted && controller.selectedMachine?.id == id)
        setState(() => machineId = id);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => switching = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (switching)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final machine = controller.selectedMachine;
      if (machine == null || machine.id != machineId)
        return Scaffold(
          appBar: AppBar(title: const Text('Máquina indisponível')),
          body: const Center(
            child: Text('Equipamento removido ou acesso encerrado.'),
          ),
        );
      return DefaultTabController(
        key: ValueKey(machine.id),
        length: 5,
        initialIndex: widget.initialTab.clamp(0, 4).toInt(),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Voltar para Máquinas',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context, 'machines'),
            ),
            title: Text(machine.name),
            actions: [
              PopupMenuButton<int>(
                tooltip: 'Trocar equipamento',
                icon: const Icon(Icons.swap_horiz),
                onSelected: changeMachine,
                itemBuilder: (_) => controller.machines
                    .map((m) => PopupMenuItem(value: m.id, child: Text(m.name)))
                    .toList(),
              ),
              IconButton(
                tooltip: 'Configurar conexão',
                icon: const Icon(Icons.cable),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MachineConnectionScreen(
                      client: controller.companyApi.client,
                      machineId: machine.id,
                      machineName: machine.name,
                      controller: machine.controller,
                      protocol: machine.protocol,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, c) {
              final view = Column(
                children: [
                  MachineNearTelemetry(machine: machine),
                  Expanded(
                    child: MachineModel3D(
                      machines: [machineSceneData(machine)],
                      selectedId: machine.id,
                    ),
                  ),
                ],
              );
              final panels = Column(
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Painel da máquina'),
                      Tab(text: 'Controle'),
                      Tab(text: 'Manutenção'),
                      Tab(text: 'Alertas'),
                      Tab(text: 'Logs'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        MachineProfilePanel(
                          key: ValueKey(machine.id),
                          machine: machine,
                          skipNear: true,
                        ),
                        Center(
                          child: FilledButton.icon(
                            onPressed: () =>
                                showMachineControlDialog(context, controller),
                            icon: const Icon(Icons.gamepad_outlined),
                            label: const Text(
                              'Abrir controle manual / automático',
                            ),
                          ),
                        ),
                        MaintenanceSection(
                          controller: controller,
                          machine: machine,
                        ),
                        AlertsSection(machine: machine),
                        controller.session?.user.role == 'ADMINISTRADOR'
                            ? LogsSection(machine: machine)
                            : const Center(
                                child: Text('Acesso restrito à administração.'),
                              ),
                      ],
                    ),
                  ),
                ],
              );
              if (c.maxWidth >= 950)
                return Row(
                  children: [
                    Expanded(flex: 5, child: view),
                    Expanded(flex: 6, child: panels),
                  ],
                );
              return ListView(
                children: [
                  SizedBox(height: c.maxWidth < 500 ? 600 : 520, child: view),
                  SizedBox(height: 650, child: panels),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

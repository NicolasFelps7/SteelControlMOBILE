import 'dart:async';

import 'package:flutter/material.dart';

import '../models/machine.dart';
import '../state/app_controller.dart';
import '../widgets/machine_model_3d.dart';
import '../widgets/machine_profile_panel.dart';
import 'machine_workspace_screen.dart';
import 'machine_control_dialog.dart';
import 'company_screen.dart';
import 'settings_screen.dart';
import '../widgets/machine_plant_board.dart';

class OperationCenterScreen extends StatefulWidget {
  const OperationCenterScreen({
    required this.controller,
    this.onMachines,
    this.machineId,
    super.key,
  });
  final AppController controller;
  final VoidCallback? onMachines;
  final int? machineId;
  @override
  State<OperationCenterScreen> createState() => _OperationCenterScreenState();
}

class _OperationCenterScreenState extends State<OperationCenterScreen>
    with WidgetsBindingObserver {
  Timer? timer;
  bool busy = false, paused = false, disposed = false;
  bool reading = false;
  String? error;
  AppController get controller => widget.controller;
  Machine? get selected => controller.selectedMachine;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialize();
    });
    timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> initialize() async {
    try {
      if (controller.machines.isEmpty) await controller.loadMachines();
      if (!mounted) return;
      final initial = controller.machines
          .where((m) => m.id == widget.machineId)
          .firstOrNull;
      if (initial != null && selected == null) await choose(initial.id);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> refresh() async {
    if (!mounted ||
        paused ||
        busy ||
        reading ||
        selected == null ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    reading = true;
    try {
      await controller.refreshSelectedMachine();
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      reading = false;
    }
  }

  Future<void> choose(int? id) async {
    if (busy || disposed) return;
    final machine = controller.machines.where((m) => m.id == id).firstOrNull;
    if (machine == null) {
      controller.clearSelectedMachine();
      return;
    }
    setState(() => busy = true);
    try {
      await controller.selectMachine(machine);
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted)
        setState(() => busy = false);
      else
        busy = false;
    }
  }

  void back() {
    controller.clearSelectedMachine();
    if (widget.onMachines != null)
      widget.onMachines!();
    else
      Navigator.maybePop(context);
  }

  Future<void> open(int tab) async {
    final machine = selected;
    if (machine == null) return;
    if (tab == 1 || tab == 6) {
      await showMachineControlDialog(context, controller, automatic: tab == 6);
      return;
    }
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MachineWorkspaceScreen(
          controller: controller,
          machineId: machine.id,
          initialTab: tab,
        ),
      ),
    );
    if (mounted && result == 'machines') back();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    paused = state != AppLifecycleState.resumed;
    if (!paused) refresh();
  }

  @override
  void dispose() {
    disposed = true;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(changed);
    super.dispose();
  }

  Widget scene(Machine? machine) => Column(
    children: [
      if (machine != null) MachineNearTelemetry(machine: machine),
      Expanded(
        child: MachineModel3D(
          factoryScene: true,
          key: ValueKey(machine?.id ?? 'fleet'),
          machines: (machine == null ? controller.machines : [machine])
              .map(machineSceneData)
              .toList(),
          selectedId: machine?.id,
          onSelect: choose,
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final machine = selected, scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: refresh,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final backButton = FilledButton.icon(
            onPressed: back,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar para Máquinas'),
          );
          final name = controller.session?.user.name.trim() ?? '';
          final initial = name.isEmpty
              ? '?'
              : name.characters.first.toUpperCase();
          final dark = Theme.of(context).brightness == Brightness.dark;
          final account = Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark
                        ? const Color(0xFF38271C)
                        : const Color(0xFFFFF1E1),
                    border: Border.all(color: const Color(0xFFC65F0A)),
                  ),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFFFB575)
                          : const Color(0xFF86400D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.session?.user.name ?? 'Conta autenticada',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      controller.session?.user.role ?? '',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Minha empresa')),
                      body: CompanyScreen(controller: controller),
                    ),
                  ),
                ),
                icon: const Icon(Icons.business_outlined),
                label: const Text('Minha empresa'),
              ),
              IconButton(
                tooltip: 'Configurações',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Configurações')),
                      body: SettingsScreen(controller: controller),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: busy ? null : refresh,
                tooltip: 'Atualizar leitura',
                icon: const Icon(Icons.refresh),
              ),
            ],
          );
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  Row(
                    children: [
                      backButton,
                      const SizedBox(width: 16),
                      Expanded(child: account),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      backButton,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: account),
                    ],
                  ),
                const SizedBox(height: 18),
                Text(
                  machine?.name ?? 'Supervisão dos equipamentos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  machine == null
                      ? 'Escolha um equipamento para consultar os sensores.'
                      : '${machine.type ?? machine.controller ?? 'Equipamento'} · ${machine.model}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey(machine?.id ?? 'fleet'),
                  initialValue: machine?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Equipamento',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Visão geral dos equipamentos'),
                    ),
                    for (final m in controller.machines)
                      DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: busy ? null : choose,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in <(int, String, IconData)>[
                      (0, 'Dados técnicos', Icons.analytics_outlined),
                      (1, 'Controle manual', Icons.gamepad_outlined),
                      if (machine?.isDobot == true)
                        (6, 'Modo automático', Icons.repeat),
                      (2, 'Manutenção', Icons.build_outlined),
                      (3, 'Alertas', Icons.warning_amber),
                      (4, 'Logs', Icons.list_alt),
                    ])
                      OutlinedButton.icon(
                        onPressed: machine == null ? null : () => open(item.$1),
                        icon: Icon(item.$3, size: 18),
                        label: Text(item.$2),
                      ),
                  ],
                ),
                SizedBox(
                  height: 3,
                  child: busy ? const LinearProgressIndicator() : null,
                ),
                error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          error!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                const SizedBox(height: 16),
                if (wide && machine != null)
                  MachinePlantBoard(
                    machine: machine,
                    scene: MachineModel3D(
                      factoryScene: true,
                      key: ValueKey('plant-${machine.id}'),
                      machines: [machineSceneData(machine)],
                      selectedId: machine.id,
                      onSelect: choose,
                    ),
                    onMaintenance: () => open(2),
                  )
                else ...[
                  SizedBox(
                    height: 590,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: scene(machine),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (machine != null)
                    MachineProfilePanel(
                      machine: machine,
                      embedded: true,
                      skipNear: true,
                    ),
                ],
                if (machine == null)
                  for (final m in controller.machines)
                    Card(
                      child: ListTile(
                        title: Text(m.name),
                        subtitle: Text(
                          '${m.type ?? m.controller ?? 'Equipamento'} · ${m.connection}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => choose(m.id),
                      ),
                    ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Juntas e sensores são dados recebidos do equipamento. A cena é representativa e não substitui proteções físicas ou validação de colisões.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

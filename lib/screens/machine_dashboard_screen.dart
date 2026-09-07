import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/app_strings.dart';
import '../core/app_theme.dart';
import '../models/machine.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';
import '../widgets/section_card.dart';
import '../widgets/industrial_hmi_panel.dart';

class MachineDashboardScreen extends StatelessWidget {
  const MachineDashboardScreen({required this.controller, required this.section, super.key});

  final AppController controller;
  final int section;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final machine = controller.selectedMachine;
    if (machine == null) return Center(child: Text(strings.get('selectEquipment')));

    return switch (section) {
      1 => ProductionSection(controller: controller, machine: machine),
      2 => MaintenanceSection(controller: controller, machine: machine),
      3 => controller.session?.user.role.toUpperCase() == 'ADMINISTRADOR'
          ? LogsSection(machine: machine)
          : _RestrictedSection(message: AppStrings.of(context).get('adminOnly')),
      4 => AlertsSection(machine: machine),
      _ => OverviewSection(controller: controller, machine: machine),
    };
  }
}

class _RestrictedSection extends StatelessWidget {
  const _RestrictedSection({required this.message});
  final String message;
  @override Widget build(BuildContext context) => Center(child: SectionCard(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.admin_panel_settings_outlined, color: SteelColors.primary, size: 48), const SizedBox(height: 14), Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))]))));
}

class OverviewSection extends StatelessWidget {
  const OverviewSection({required this.controller, required this.machine, super.key});

  final AppController controller;
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return RefreshIndicator(
      onRefresh: controller.refreshSelectedMachine,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1050 ? 4 : constraints.maxWidth >= 620 ? 2 : 1;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                sliver: SliverToBoxAdapter(child: _MachineHero(machine: machine)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 132,
                  ),
                  delegate: SliverChildListDelegate([
                    MetricCard(label: strings.get('temperature'), value: '${machine.temperature.toStringAsFixed(1)} °C', icon: Icons.thermostat_rounded, color: _temperatureColor(machine.temperature)),
                    MetricCard(label: strings.get('energy'), value: '${machine.energy.toStringAsFixed(0)}%', icon: Icons.bolt_rounded, color: SteelColors.primary),
                    MetricCard(label: strings.get('totalProduction'), value: '${machine.production}', caption: strings.get('producedParts'), icon: Icons.inventory_2_outlined, color: SteelColors.success),
                    MetricCard(label: strings.get('cycles'), value: '${machine.cycles}', caption: strings.translate(machine.nextMaintenance), icon: Icons.sync_rounded, color: SteelColors.warning),
                  ]),
                ),
              ),
              if (machine.hasIndustrialHmi)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                  sliver: SliverToBoxAdapter(
                    child: IndustrialHmiPanel(controller: controller, machine: machine),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                sliver: SliverToBoxAdapter(
                  child: _ControllerDiagnostics(
                    controller: controller,
                    machine: machine,
                  ),
                ),
              ),
              if (machine.isDobot)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                  sliver: SliverToBoxAdapter(
                    child: DobotPanel(controller: controller, machine: machine),
                  ),
                ),
              if (machine.simulation)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                  sliver: SliverToBoxAdapter(child: _SimulationPanel(controller: controller, machine: machine)),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          );
        },
      ),
    );
  }

  Color _temperatureColor(double value) {
    if (value >= 70) return SteelColors.danger;
    if (value >= 55) return SteelColors.warning;
    return SteelColors.success;
  }
}

class _MachineHero extends StatelessWidget {
  const _MachineHero({required this.machine});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final online = machine.isOnline;
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [SteelColors.ink, Color(0xFF3D4854)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(width: 62, height: 62, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(18)), child: Icon(machine.isDobot ? Icons.precision_manufacturing_rounded : Icons.factory_outlined, color: Colors.white, size: 33)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.get(machine.isDobot ? 'robotCellPanel' : 'machineExclusivePanel'), style: const TextStyle(color: Color(0xFFBCC5CD), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.25)),
                const SizedBox(height: 6),
                Text(machine.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                Text('${machine.controller ?? machine.model} • ${machine.protocol ?? machine.sector}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
            child: Row(children: [Icon(Icons.circle, color: online ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5), size: 10), const SizedBox(width: 7), Text(online ? strings.get('online') : strings.get('waitingTelemetry'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))]),
          ),
        ],
      ),
    );
  }
}

class _ControllerDiagnostics extends StatefulWidget {
  const _ControllerDiagnostics({
    required this.controller,
    required this.machine,
  });

  final AppController controller;
  final Machine machine;

  @override
  State<_ControllerDiagnostics> createState() => _ControllerDiagnosticsState();
}

class _ControllerDiagnosticsState extends State<_ControllerDiagnostics> {
  late Future<Map<String, dynamic>> _diagnostics;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant _ControllerDiagnostics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machine.id != widget.machine.id || oldWidget.machine != widget.machine) _reload();
  }

  void _reload() {
    _diagnostics = widget.controller.machinesApi.diagnostics(widget.machine.id);
  }

  Future<void> _refresh() async {
    final next = widget.controller.machinesApi.diagnostics(widget.machine.id);
    if (mounted) setState(() => _diagnostics = next);
    try {
      await Future.wait([next, widget.controller.refreshSelectedMachine()]);
    } catch (_) {
      // O painel continua exibindo os dados locais quando o diagnóstico remoto falha.
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _diagnostics,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final items = _controllerDiagnosticItems(widget.machine, data, strings);
        final remoteOk = snapshot.hasData && !snapshot.hasError;
        final controllerName =
            widget.machine.controller?.trim().isNotEmpty == true
                ? widget.machine.controller!
                : widget.machine.model;

        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SteelColors.primary.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.monitor_heart_outlined,
                      color: SteelColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.get('controllerDiagnostics'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$controllerName • ${strings.get('controllerResourcesCaption')}',
                          style: const TextStyle(
                            color: SteelColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      tooltip: strings.get('refreshDiagnostics'),
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DiagnosticStatusBadge(
                    label: remoteOk
                        ? strings.get('liveDiagnostics')
                        : strings.get('localDiagnostics'),
                    color: remoteOk ? SteelColors.success : SteelColors.warning,
                    icon: remoteOk
                        ? Icons.cloud_done_outlined
                        : Icons.offline_bolt_outlined,
                  ),
                  _DiagnosticStatusBadge(
                    label: widget.machine.simulation
                        ? strings.get('simulation')
                        : strings.get('real'),
                    color: widget.machine.simulation
                        ? SteelColors.primary
                        : SteelColors.success,
                    icon: widget.machine.simulation
                        ? Icons.science_outlined
                        : Icons.memory_rounded,
                  ),
                ],
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 10),
                Text(
                  strings.get('diagnosticsFallback'),
                  style: const TextStyle(
                    color: SteelColors.warning,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 980
                      ? 4
                      : width >= 620
                          ? 3
                          : width >= 390
                              ? 2
                              : 1;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 112,
                    children: items
                        .map(
                          (item) => _DiagnosticTile(
                            item: item,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              if (data.isNotEmpty) ...[
                const SizedBox(height: 10),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.data_object_rounded,
                      color: SteelColors.primary,
                    ),
                    title: Text(
                      strings.get('extendedDiagnostics'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      strings.get('extendedDiagnosticsCaption'),
                      style: const TextStyle(
                        color: SteelColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    children: _diagnosticDetailRows(data)
                        .map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 160,
                                  child: Text(
                                    _prettyDiagnosticKey(row.$1),
                                    style: const TextStyle(
                                      color: SteelColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SelectableText(
                                    row.$2,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DiagnosticItem {
  const _DiagnosticItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({required this.item});

  final _DiagnosticItem item;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: .34),
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, size: 20, color: SteelColors.primary),
            const Spacer(),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SteelColors.muted,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
}

class _DiagnosticStatusBadge extends StatelessWidget {
  const _DiagnosticStatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          border: Border.all(color: color.withValues(alpha: .16)),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

List<_DiagnosticItem> _controllerDiagnosticItems(
  Machine machine,
  Map<String, dynamic> diagnostics,
  AppStrings strings,
) {
  final source = <String, dynamic>{
    'diagnostics': diagnostics,
    'extra': machine.extraData,
    'integration': machine.integrationMeta,
  };
  final unavailable = strings.get('notConfigured');

  dynamic find(List<String> aliases) => _deepDiagnosticFind(source, aliases);

  String value(
    List<String> aliases, {
    String? fallback,
    String unit = '',
  }) {
    final found = find(aliases);
    final raw = found ?? fallback;
    if (raw == null || '$raw'.trim().isEmpty) return unavailable;
    if (raw is bool) {
      return raw ? strings.get('yes') : strings.get('no');
    }
    final text = '$raw'.trim();
    return unit.isEmpty ? text : '$text $unit';
  }

  final controller =
      (machine.controller ?? machine.type ?? machine.model).toUpperCase();
  final common = <_DiagnosticItem>[
    _DiagnosticItem(
      label: strings.get('connection'),
      value: machine.isOnline ? strings.get('online') : strings.get('offline'),
      icon: Icons.lan_outlined,
    ),
    _DiagnosticItem(
      label: strings.get('protocol'),
      value: machine.protocol?.trim().isNotEmpty == true
          ? machine.protocol!
          : unavailable,
      icon: Icons.hub_outlined,
    ),
  ];

  if (controller.contains('ESP32')) {
    return [
      ...common,
      _DiagnosticItem(
        label: strings.get('signalQuality'),
        value: value(
          ['rssi', 'signalQuality', 'qualidadeSinal', 'wifiRssi'],
          fallback: machine.signalQuality?.toStringAsFixed(0),
          unit: machine.signalQuality == null ? '' : '%',
        ),
        icon: Icons.wifi_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('heartbeat'),
        value: value(['heartbeat', 'lastHeartbeat', 'ultimoHeartbeat']),
        icon: Icons.favorite_border_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('latency'),
        value: value(
          ['latencyMs', 'latenciaMs', 'latency'],
          fallback: machine.latencyMs?.toStringAsFixed(0),
          unit: machine.latencyMs == null ? '' : 'ms',
        ),
        icon: Icons.speed_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('sensors'),
        value: value(['sensors', 'sensores', 'sensorCount']),
        icon: Icons.sensors_outlined,
      ),
      _DiagnosticItem(
        label: strings.get('readInterval'),
        value: '${machine.readInterval} ms',
        icon: Icons.timer_outlined,
      ),
      _DiagnosticItem(
        label: strings.get('host'),
        value: machine.host ?? unavailable,
        icon: Icons.router_outlined,
      ),
    ];
  }

  if (controller.contains('DOBOT')) {
    final x = value(['pose.x', 'x', 'positionX']);
    final y = value(['pose.y', 'y', 'positionY']);
    final z = value(['pose.z', 'z', 'positionZ']);
    return [
      ...common,
      _DiagnosticItem(
        label: strings.get('mode'),
        value: value(['mode', 'modo', 'dobot.mode']),
        icon: Icons.tune_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('serialPort'),
        value: value(['serialPort', 'portName', 'comPort', 'portaSerial']),
        icon: Icons.usb_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('baudRate'),
        value: value(['baudRate', 'baud', 'velocidadeSerial']),
        icon: Icons.swap_horiz_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('endEffectorPosition'),
        value: 'X $x • Y $y • Z $z',
        icon: Icons.my_location_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('alarms'),
        value: value(['alarms', 'alarmCount', 'alertas', 'alarmsActive']),
        icon: Icons.warning_amber_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('safeQueue'),
        value: value(['queue', 'queueState', 'fila', 'filaSegura']),
        icon: Icons.queue_play_next_rounded,
      ),
    ];
  }

  if (controller.contains('CLP') || controller.contains('PLC')) {
    return [
      ...common,
      _DiagnosticItem(
        label: strings.get('scanTime'),
        value: value(['scanTimeMs', 'scanTime', 'tempoScan'], unit: 'ms'),
        icon: Icons.timer_outlined,
      ),
      _DiagnosticItem(
        label: strings.get('plcIo'),
        value: value(['io', 'ioState', 'inputsOutputs', 'entradasSaidas']),
        icon: Icons.input_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('registers'),
        value: value(['registers', 'registerCount', 'registradores']),
        icon: Icons.data_array_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('unitId'),
        value: machine.unitId?.toString() ?? value(['unitId', 'slaveId']),
        icon: Icons.numbers_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('host'),
        value: machine.host ?? unavailable,
        icon: Icons.dns_outlined,
      ),
      _DiagnosticItem(
        label: strings.get('latency'),
        value: value(['latencyMs', 'latenciaMs'], unit: 'ms'),
        icon: Icons.speed_rounded,
      ),
    ];
  }

  if (controller.contains('CNC')) {
    return [
      ...common,
      _DiagnosticItem(
        label: strings.get('spindleSpeed'),
        value: value(['spindleRpm', 'rpm', 'spindleSpeed'], unit: 'RPM'),
        icon: Icons.rotate_right_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('feed'),
        value: value(['feedRate', 'feed', 'avanco']),
        icon: Icons.trending_flat_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('program'),
        value: value(['program', 'programName', 'programa']),
        icon: Icons.description_outlined,
      ),
      _DiagnosticItem(
        label: strings.get('tool'),
        value: value(['tool', 'toolNumber', 'ferramenta']),
        icon: Icons.build_circle_outlined,
      ),
      _DiagnosticItem(
        label: strings.get('axes'),
        value: value(['axes', 'axisCount', 'eixos']),
        icon: Icons.open_with_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('machineLoad'),
        value: value(['load', 'machineLoad', 'carga'], unit: '%'),
        icon: Icons.speed_outlined,
      ),
    ];
  }

  if (controller.contains('ROBOT')) {
    return [
      ...common,
      _DiagnosticItem(
        label: strings.get('mode'),
        value: value(['mode', 'modo', 'robotMode']),
        icon: Icons.tune_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('axes'),
        value: value(['axes', 'axisCount', 'eixos']),
        icon: Icons.open_with_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('tool'),
        value: value(['tool', 'toolName', 'ferramenta']),
        icon: Icons.build_outlined,
      ),
      _DiagnosticItem(
        label: strings.get('safety'),
        value: value(['safety', 'safetyState', 'seguranca']),
        icon: Icons.health_and_safety_outlined,
      ),
      _DiagnosticItem(
        label: strings.get('cycleTime'),
        value: value(['cycleTimeMs', 'cycleTime', 'tempoCiclo'], unit: 'ms'),
        icon: Icons.sync_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('controllerState'),
        value: value(['controllerState', 'state', 'estadoControlador']),
        icon: Icons.memory_rounded,
      ),
    ];
  }

  if (controller.contains('GATEWAY')) {
    return [
      ...common,
      _DiagnosticItem(
        label: strings.get('onlineDevices'),
        value: value(['devicesOnline', 'onlineDevices', 'dispositivosOnline']),
        icon: Icons.devices_other_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('protocols'),
        value: value(['protocols', 'protocolos']),
        icon: Icons.account_tree_outlined,
      ),
      _DiagnosticItem(
        label: strings.get('traffic'),
        value: value(['traffic', 'throughput', 'trafego']),
        icon: Icons.swap_vert_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('latency'),
        value: value(
          ['latencyMs', 'latenciaMs'],
          fallback: machine.latencyMs?.toStringAsFixed(0),
          unit: 'ms',
        ),
        icon: Icons.speed_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('endpoint'),
        value: machine.endpoint ?? unavailable,
        icon: Icons.link_rounded,
      ),
      _DiagnosticItem(
        label: strings.get('readInterval'),
        value: '${machine.readInterval} ms',
        icon: Icons.timer_outlined,
      ),
    ];
  }

  return [
    ...common,
    _DiagnosticItem(
      label: strings.get('vibration'),
      value: '${machine.vibration.toStringAsFixed(2)} mm/s',
      icon: Icons.vibration_rounded,
    ),
    _DiagnosticItem(
      label: strings.get('current'),
      value: '${machine.current.toStringAsFixed(2)} A',
      icon: Icons.electric_bolt_outlined,
    ),
    _DiagnosticItem(
      label: strings.get('maintenance'),
      value: strings.translate(machine.maintenanceStatus),
      icon: Icons.build_outlined,
    ),
    _DiagnosticItem(
      label: strings.get('readInterval'),
      value: '${machine.readInterval} ms',
      icon: Icons.timer_outlined,
    ),
  ];
}

dynamic _deepDiagnosticFind(dynamic source, List<String> aliases) {
  final normalizedAliases = aliases
      .map((item) => item.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))
      .toSet();

  dynamic walk(dynamic value, int depth) {
    if (depth > 5) return null;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = '${entry.key}'
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (normalizedAliases.contains(key) && entry.value != null) {
          return entry.value;
        }
      }
      for (final entry in value.entries) {
        final found = walk(entry.value, depth + 1);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final item in value.take(20)) {
        final found = walk(item, depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  return walk(source, 0);
}

List<(String, String)> _diagnosticDetailRows(Map<String, dynamic> data) {
  final rows = <(String, String)>[];

  void walk(dynamic value, String prefix, int depth) {
    if (rows.length >= 24 || depth > 3) return;
    if (value is Map) {
      for (final entry in value.entries) {
        final next = prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}';
        walk(entry.value, next, depth + 1);
      }
      return;
    }
    if (value is List) {
      rows.add((prefix, value.take(10).map((item) => '$item').join(', ')));
      return;
    }
    if (value != null) rows.add((prefix, '$value'));
  }

  walk(data, '', 0);
  return rows;
}

String _prettyDiagnosticKey(String value) {
  if (value.trim().isEmpty) return '-';
  final spaced = value
      .replaceAll(RegExp(r'[_\.]+'), ' ')
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

class _SimulationPanel extends StatelessWidget {
  const _SimulationPanel({required this.controller, required this.machine});
  final AppController controller;
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [const Icon(Icons.science_outlined, color: SteelColors.primary), const SizedBox(width: 10), Text(strings.get('demoMode'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 6),
            Text(strings.get('demoCaption'), style: const TextStyle(color: SteelColors.muted)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                _ScenarioButton(label: strings.get('normal'), scenario: 'normal', controller: controller, machine: machine),
                _ScenarioButton(label: strings.get('heating'), scenario: 'aquecimento', controller: controller, machine: machine),
                _ScenarioButton(label: strings.get('criticalVibration'), scenario: 'vibracao', controller: controller, machine: machine),
                _ScenarioButton(label: strings.get('critical'), scenario: 'critico', controller: controller, machine: machine),
                _ScenarioButton(label: strings.get('normalize'), scenario: 'normalizar', controller: controller, machine: machine),
              ],
            ),
          ],
        ),
      );
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({required this.label, required this.scenario, required this.controller, required this.machine});
  final String label;
  final String scenario;
  final AppController controller;
  final Machine machine;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: () async {
          try {
            controller.replaceSelectedMachine(
              await controller.machinesApi.runScenario(machine.id, scenario),
            );
          } on ApiException catch (exception) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
          }
        },
        child: Text(label),
      );
}

class DobotPanel extends StatelessWidget {
  const DobotPanel({required this.controller, required this.machine, super.key});
  final AppController controller;
  final Machine machine;

  dynamic _extra(String group, String key) {
    final value = machine.extraData[group];
    return value is Map ? value[key] : null;
  }

  @override
  Widget build(BuildContext context) {
    final axes = ['X', 'Y', 'Z', 'R'];
    final joints = ['J1', 'J2', 'J3', 'J4'];
    final strings = AppStrings.of(context);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            crossAxisCount: constraints.maxWidth >= 700 ? 2 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 180,
            children: [
              SectionCard(child: _ValuesBlock(title: strings.get('endEffectorPosition'), labels: axes, values: axes.map((item) => '${_extra('pose', item.toLowerCase()) ?? '--'}').toList())),
              SectionCard(child: _ValuesBlock(title: strings.get('jointAngles'), labels: joints, values: joints.map((item) => '${_extra('joints', item.toLowerCase()) ?? '--'}').toList())),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.get('supervisedControl'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(strings.get('secureQueueCaption'), style: const TextStyle(color: SteelColors.muted)),
              const SizedBox(height: 17),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _DobotCommand(label: 'HOME', command: 'DOBOT_HOME', controller: controller, machine: machine),
                  _DobotCommand(label: strings.get('stop'), command: 'DOBOT_STOP', controller: controller, machine: machine, danger: true),
                  _DobotCommand(label: strings.get('clearAlarms'), command: 'DOBOT_CLEAR_ALARMS', controller: controller, machine: machine),
                  _DobotCommand(label: strings.get('suctionOn'), command: 'DOBOT_SUCTION_ON', controller: controller, machine: machine),
                  _DobotCommand(label: strings.get('suctionOff'), command: 'DOBOT_SUCTION_OFF', controller: controller, machine: machine),
                  _DobotCommand(label: strings.get('openGripper'), command: 'DOBOT_GRIPPER_OPEN', controller: controller, machine: machine),
                  _DobotCommand(label: strings.get('closeGripper'), command: 'DOBOT_GRIPPER_CLOSE', controller: controller, machine: machine),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DobotPtpPanel(controller: controller, machine: machine),
      ],
    );
  }
}

class _DobotPtpPanel extends StatefulWidget {
  const _DobotPtpPanel({required this.controller, required this.machine});

  final AppController controller;
  final Machine machine;

  @override
  State<_DobotPtpPanel> createState() => _DobotPtpPanelState();
}

class _DobotPtpPanelState extends State<_DobotPtpPanel> {
  final _x = TextEditingController();
  final _y = TextEditingController();
  final _z = TextEditingController();
  final _r = TextEditingController();
  double _speed = 40;
  bool _sending = false;

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    _z.dispose();
    _r.dispose();
    super.dispose();
  }

  double? _value(TextEditingController controller) => double.tryParse(controller.text.replaceAll(',', '.'));

  Future<void> _send() async {
    final values = [_value(_x), _value(_y), _value(_z), _value(_r)];
    if (values.any((value) => value == null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).get('ptpFieldsRequired'))));
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.controller.machinesApi.sendDobotCommand(widget.machine.id, 'DOBOT_PTP', {
        'x': values[0],
        'y': values[1],
        'z': values[2],
        'r': values[3],
        'velocidade': _speed.round(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).get('ptpSent'))));
    } on ApiException catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) { final strings = AppStrings.of(context); return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.control_camera_rounded, color: SteelColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(strings.get('ptpMovement'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                Chip(label: Text(strings.get('protectedMovement'))),
              ],
            ),
            const SizedBox(height: 5),
            Text(strings.get('safetyValidationCaption'), style: const TextStyle(color: SteelColors.muted)),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 720 ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AxisField(width: width, controller: _x, label: 'X (mm)'),
                    _AxisField(width: width, controller: _y, label: 'Y (mm)'),
                    _AxisField(width: width, controller: _z, label: 'Z (mm)'),
                    _AxisField(width: width, controller: _r, label: 'R (°)'),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(strings.get('speed'), style: const TextStyle(fontWeight: FontWeight.w700)),
                Expanded(child: Slider(value: _speed, min: 1, max: 100, divisions: 99, label: '${_speed.round()}%', onChanged: (value) => setState(() => _speed = value))),
                SizedBox(width: 48, child: Text('${_speed.round()}%', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
                const SizedBox(width: 14),
                FilledButton.icon(onPressed: _sending ? null : _send, icon: const Icon(Icons.send_rounded), label: Text(_sending ? strings.get('sending') : strings.get('sendPtp'))),
              ],
            ),
          ],
        ),
      ); }
}

class _AxisField extends StatelessWidget {
  const _AxisField({required this.width, required this.controller, required this.label});
  final double width;
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _ValuesBlock extends StatelessWidget {
  const _ValuesBlock({required this.title, required this.labels, required this.values});
  final String title;
  final List<String> labels;
  final List<String> values;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 15),
          Expanded(
            child: Row(
              children: List.generate(labels.length, (index) => Expanded(child: Container(margin: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 7), decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .07), borderRadius: BorderRadius.circular(13)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(labels[index], style: const TextStyle(color: SteelColors.primary, fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text(values[index], style: const TextStyle(fontWeight: FontWeight.w800))])))),
            ),
          ),
        ],
      );
}

class _DobotCommand extends StatelessWidget {
  const _DobotCommand({required this.label, required this.command, required this.controller, required this.machine, this.danger = false});
  final String label;
  final String command;
  final AppController controller;
  final Machine machine;
  final bool danger;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
        style: danger ? FilledButton.styleFrom(backgroundColor: const Color(0xFFFEE2E2), foregroundColor: SteelColors.danger) : null,
        onPressed: () async {
          try {
            await controller.machinesApi.sendDobotCommand(machine.id, command);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).get('commandSent').replaceAll('{command}', label))));
          } on ApiException catch (exception) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
          }
        },
        child: Text(label),
      );
}

class ProductionSection extends StatefulWidget {
  const ProductionSection({required this.controller, required this.machine, super.key});
  final AppController controller;
  final Machine machine;

  @override
  State<ProductionSection> createState() => _ProductionSectionState();
}

class _ProductionSectionState extends State<ProductionSection> {
  late Future<List<Map<String, dynamic>>> _telemetry;

  @override
  void initState() {
    super.initState();
    _telemetry = widget.controller.machinesApi.telemetry(widget.machine.id);
  }

  @override
  void didUpdateWidget(covariant ProductionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machine.id != widget.machine.id) {
      _telemetry = widget.controller.machinesApi.telemetry(widget.machine.id);
    }
  }

  Future<void> _refresh() async {
    final next = widget.controller.machinesApi.telemetry(widget.machine.id);
    setState(() => _telemetry = next);
    await Future.wait([next, widget.controller.refreshSelectedMachine()]);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final profile = _operationalProfile(widget.machine, strings);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _telemetry,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        final points = _productionPoints(items, widget.machine);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(22),
            children: [
              _ProductionHeader(machine: widget.machine, profile: profile),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final chart = _ProductionChartCard(
                    profile: profile,
                    points: points,
                    loading: snapshot.connectionState == ConnectionState.waiting,
                  );
                  final summary = _ProductiveSummary(machine: widget.machine, profile: profile);
                  if (constraints.maxWidth >= 820) {
                    return SizedBox(
                      height: constraints.maxWidth < 1050 ? 510 : 480,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 2, child: chart),
                          const SizedBox(width: 14),
                          Expanded(child: summary),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      SizedBox(height: 330, child: chart),
                      const SizedBox(height: 14),
                      summary,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              _ProductionMetrics(machine: widget.machine, points: points),
            ],
          ),
        );
      },
    );
  }
}

class _ProductionHeader extends StatelessWidget {
  const _ProductionHeader({required this.machine, required this.profile});
  final Machine machine;
  final _OperationalProfile profile;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(16)), child: Icon(profile.icon, color: SteelColors.primary)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${strings.get('operationTelemetry')} ${profile.name}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(strings.get('operationTelemetryCaption'), style: const TextStyle(color: SteelColors.muted))])),
        const SizedBox(width: 12),
        _ConnectionBadge(machine: machine),
      ],
    );
  }
}

class _ProductionChartCard extends StatelessWidget {
  const _ProductionChartCard({required this.profile, required this.points, required this.loading});
  final _OperationalProfile profile;
  final List<_ProductionPoint> points;
  final bool loading;

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.of(context).get('productionChart'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(profile.chartLabel, style: const TextStyle(color: SteelColors.muted, fontSize: 12)),
            const SizedBox(height: 15),
            Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : _ProductionBars(points: points)),
          ],
        ),
      );
}

class _ProductiveSummary extends StatelessWidget {
  const _ProductiveSummary({required this.machine, required this.profile});
  final Machine machine;
  final _OperationalProfile profile;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.get('productiveSummary'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          _SummaryLine(label: profile.primaryLabel, value: '${machine.production}'),
          _SummaryLine(label: strings.get('cyclesReported'), value: '${machine.cycles}'),
          _SummaryLine(label: strings.get('status'), value: strings.translate(machine.status), color: _statusColor(machine)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .08), border: Border.all(color: SteelColors.primary.withValues(alpha: .18)), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile.metricLabel, style: const TextStyle(color: SteelColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
              const SizedBox(height: 7),
              Text(profile.metricValue, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${strings.get('compatibleModules')}: ${profile.name}.', style: const TextStyle(color: SteelColors.muted, fontSize: 12, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 7, runSpacing: 7, children: profile.resources
                    .map(
                      (item) => Chip(
                        label: Text(item, style: const TextStyle(fontSize: 11)),
                        visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList()),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ProductionMetrics extends StatelessWidget {
  const _ProductionMetrics({required this.machine, required this.points});
  final Machine machine;
  final List<_ProductionPoint> points;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final values = points.map((point) => point.value).toList();
    final peak = values.isEmpty ? machine.production.toDouble() : values.reduce((a, b) => a > b ? a : b);
    final average = values.isEmpty ? machine.production.toDouble() : values.reduce((a, b) => a + b) / values.length;
    final lastLabel = points.isEmpty ? strings.get('notConfigured') : points.last.label;
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700 ? 3 : 1;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 128,
        children: [
          MetricCard(label: strings.get('productionPeak'), value: peak.toStringAsFixed(0), icon: Icons.trending_up_rounded, color: SteelColors.primary),
          MetricCard(label: strings.get('productionAverage'), value: average.toStringAsFixed(1), icon: Icons.analytics_outlined, color: SteelColors.success),
          MetricCard(label: strings.get('lastReading'), value: lastLabel, icon: Icons.schedule_rounded, color: SteelColors.warning),
        ],
      );
    });
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: SteelColors.muted))), const SizedBox(width: 10), Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color))]),
      );
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.machine});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final color = machine.isOnline ? SteelColors.success : SteelColors.warning;
    final label = machine.simulation ? strings.get('simulation') : machine.isOnline ? strings.get('online') : strings.get('offline');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(color: color.withValues(alpha: .10), border: Border.all(color: color.withValues(alpha: .20)), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 9, color: color), const SizedBox(width: 7), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11))]),
    );
  }
}

class _ProductionBars extends StatelessWidget {
  const _ProductionBars({required this.points});
  final List<_ProductionPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return Center(child: Text(AppStrings.of(context).get('noTelemetry'), textAlign: TextAlign.center, style: const TextStyle(color: SteelColors.muted)));
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _BarChartPainter(
        points: points,
        gridColor: dark ? const Color(0xFF3D4854) : const Color(0xFFDDE3E8),
        labelColor: dark ? const Color(0xFF9AA6B1) : SteelColors.muted,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.points, required this.gridColor, required this.labelColor});
  final List<_ProductionPoint> points;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const bottom = 30.0;
    final top = 8.0;
    final right = 8.0;
    final chartWidth = math.max(1.0, size.width - left - right).toDouble();
    final chartHeight = math.max(1.0, size.height - top - bottom).toDouble();
    final largestPoint = points.map((point) => point.value).reduce((a, b) => a > b ? a : b);
    final maxValue = math.max(1.0, largestPoint).toDouble();
    final grid = Paint()..color = gridColor..strokeWidth = 1;
    final labelStyle = TextStyle(color: labelColor, fontSize: 10);
    for (var index = 0; index <= 4; index++) {
      final y = top + chartHeight * index / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      final value = maxValue * (4 - index) / 4;
      _paintLabel(canvas, value.toStringAsFixed(0), Offset(0, y - 6), labelStyle, width: left - 7, align: TextAlign.right);
    }

    final slot = chartWidth / points.length;
    final barWidth = math.min(42.0, slot * .56).toDouble();
    final paint = Paint()..color = SteelColors.primary;
    final labelEvery = math.max(1, (points.length / 6).ceil()).toInt();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final height = chartHeight * point.value / maxValue;
      final centerX = left + slot * index + slot / 2;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(centerX - barWidth / 2, top + chartHeight - height, barWidth, height), const Radius.circular(5));
      canvas.drawRRect(rect, paint);
      if (index % labelEvery == 0 || index == points.length - 1) {
        _paintLabel(canvas, point.label, Offset(centerX - slot / 2, top + chartHeight + 7), labelStyle, width: slot, align: TextAlign.center);
      }
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset offset, TextStyle style, {required double width, required TextAlign align}) {
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textAlign: align, maxLines: 1)..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) => oldDelegate.points != points || oldDelegate.gridColor != gridColor;
}

class _ProductionPoint {
  const _ProductionPoint({required this.value, required this.label});
  final double value;
  final String label;
}

class _OperationalProfile {
  const _OperationalProfile({required this.name, required this.chartLabel, required this.primaryLabel, required this.metricLabel, required this.metricValue, required this.resources, required this.icon});
  final String name;
  final String chartLabel;
  final String primaryLabel;
  final String metricLabel;
  final String metricValue;
  final List<String> resources;
  final IconData icon;
}

_OperationalProfile _operationalProfile(Machine machine, AppStrings strings) {
  final controller = (machine.controller ?? machine.type ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
  final unavailable = strings.get('notConfigured');
  String number(dynamic value, String unit) {
    final parsed = value is num ? value : double.tryParse('$value');
    return parsed == null ? unavailable : '${parsed is double ? parsed.toStringAsFixed(parsed % 1 == 0 ? 0 : 1) : parsed} $unit'.trim();
  }
  dynamic nested(String group, String key) {
    final extra = machine.extraData[group];
    if (extra is Map && extra[key] != null) return extra[key];
    final meta = machine.integrationMeta[group];
    return meta is Map ? meta[key] : null;
  }

  if (controller.contains('ESP32')) {
    return _OperationalProfile(name: 'ESP32 / IoT', chartLabel: strings.get('esp32Activity'), primaryLabel: strings.get('processesCounted'), metricLabel: strings.get('signalQuality'), metricValue: number(machine.signalQuality, '%'), resources: [strings.get('sensors'), strings.get('wifiRssi'), strings.get('heartbeat')], icon: Icons.memory_rounded);
  }
  if (controller.contains('DOBOT')) {
    return _OperationalProfile(name: 'Dobot Magician', chartLabel: strings.get('dobotOperations'), primaryLabel: strings.get('processesCounted'), metricLabel: strings.get('controllerIndicator'), metricValue: '${nested('dobot', 'mode') ?? unavailable}', resources: [strings.get('movements'), strings.get('endEffectorPosition'), strings.get('safeQueue')], icon: Icons.precision_manufacturing_rounded);
  }
  if (controller.contains('CLP') || controller.contains('PLC')) {
    return _OperationalProfile(name: 'CLP / PLC', chartLabel: strings.get('plcProduction'), primaryLabel: strings.get('totalProduction'), metricLabel: strings.get('scanTime'), metricValue: number(nested('plc', 'scanTimeMs'), 'ms'), resources: [strings.get('process'), strings.get('plcIo'), strings.get('registers')], icon: Icons.developer_board_rounded);
  }
  if (controller.contains('CNC')) {
    return _OperationalProfile(name: 'CNC', chartLabel: strings.get('machinedParts'), primaryLabel: strings.get('totalProduction'), metricLabel: strings.get('spindleSpeed'), metricValue: number(nested('cnc', 'spindleRpm'), 'RPM'), resources: [strings.get('spindle'), strings.get('feed'), strings.get('program')], icon: Icons.settings_suggest_rounded);
  }
  if (controller.contains('ROBOT')) {
    return _OperationalProfile(name: strings.get('robotController'), chartLabel: strings.get('robotCycles'), primaryLabel: strings.get('processesCounted'), metricLabel: strings.get('controllerIndicator'), metricValue: '${nested('robot', 'mode') ?? unavailable}', resources: [strings.get('axes'), strings.get('tool'), strings.get('safety')], icon: Icons.precision_manufacturing_outlined);
  }
  if (controller.contains('GATEWAY')) {
    return _OperationalProfile(name: strings.get('industrialGateway'), chartLabel: strings.get('gatewayActivity'), primaryLabel: strings.get('processesCounted'), metricLabel: strings.get('onlineDevices'), metricValue: number(nested('gateway', 'devicesOnline'), ''), resources: [strings.get('devices'), strings.get('protocols'), strings.get('traffic')], icon: Icons.hub_outlined);
  }
  return _OperationalProfile(name: machine.controller ?? machine.model, chartLabel: strings.get('productionMachine'), primaryLabel: strings.get('totalProduction'), metricLabel: strings.get('averageLoad'), metricValue: '${machine.energy.toStringAsFixed(0)}%', resources: [strings.get('production'), strings.get('telemetry'), strings.get('alerts')], icon: Icons.factory_outlined);
}

List<_ProductionPoint> _productionPoints(List<Map<String, dynamic>> items, Machine machine) {
  final dated = items.map((item) {
    final raw = item['producao'] ?? item['production'] ?? item['totalProduzido'];
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
    final date = DateTime.tryParse('${item['criadoEm'] ?? item['timestamp'] ?? item['data'] ?? ''}')?.toLocal();
    return (value: value, date: date);
  }).where((item) => item.value != null).toList();
  dated.sort((a, b) {
    if (a.date == null || b.date == null) return 0;
    return a.date!.compareTo(b.date!);
  });
  final selected = dated.length > 12 ? dated.sublist(dated.length - 12) : dated;
  if (selected.isEmpty) {
    if (!machine.isOnline && !machine.simulation) return const [];
    return [
      _ProductionPoint(
        value: machine.production.toDouble(),
        label: DateFormat('HH:mm:ss').format(DateTime.now()),
      ),
    ];
  }
  return selected.asMap().entries.map((entry) {
    final date = entry.value.date;
    return _ProductionPoint(value: entry.value.value!, label: date == null ? '${entry.key + 1}' : DateFormat('HH:mm:ss').format(date));
  }).toList();
}

Color _statusColor(Machine machine) {
  final status = machine.status.toLowerCase();
  if (!machine.isOnline && !machine.simulation) return SteelColors.warning;
  if (status.contains('alert') || status.contains('aten')) return SteelColors.warning;
  if (status.contains('critic') || status.contains('falha') || status.contains('parad')) return SteelColors.danger;
  return SteelColors.success;
}

class MaintenanceSection extends StatefulWidget {
  const MaintenanceSection({required this.controller, required this.machine, super.key});
  final AppController controller;
  final Machine machine;

  @override
  State<MaintenanceSection> createState() => _MaintenanceSectionState();
}

class _MaintenanceSectionState extends State<MaintenanceSection> {
  late Future<List<MaintenanceRecord>> _items;
  bool _busy = false;
  bool get _admin => widget.controller.session?.user.role.toUpperCase() == 'ADMINISTRADOR';
  bool get _canRegister {
    final role = widget.controller.session?.user.role.toUpperCase();
    return role == 'ADMINISTRADOR' || role == 'SUPERVISOR' || role == 'TECNICO';
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _items = widget.controller.machinesApi.maintenance(widget.machine.id);

  @override
  void didUpdateWidget(covariant MaintenanceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machine.id != widget.machine.id) _reload();
  }

  Future<void> _refresh() async {
    final nextItems = widget.controller.machinesApi.maintenance(widget.machine.id);
    if (mounted) setState(() => _items = nextItems);
    await Future.wait([nextItems, widget.controller.refreshSelectedMachine()]);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return FutureBuilder<List<MaintenanceRecord>>(
        future: _items,
        builder: (context, snapshot) => RefreshIndicator(onRefresh: _refresh, child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            LayoutBuilder(builder: (context, constraints) {
              final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('maintenanceCenter'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${strings.get('maintenanceHistory')} • ${widget.machine.name}', style: const TextStyle(color: SteelColors.muted))]);
              final button = FilledButton.icon(onPressed: _busy ? null : _openForm, icon: const Icon(Icons.add_rounded), label: Text(strings.get('register')));
              if (constraints.maxWidth < 520) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [copy, if (_canRegister) ...[const SizedBox(height: 14), button]]);
              return Row(children: [Expanded(child: copy), if (_canRegister) button]);
            }),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 880 ? 4 : constraints.maxWidth >= 500 ? 2 : 1;
              return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, mainAxisExtent: columns == 4 ? 180 : 150, children: [
                MetricCard(label: strings.get('lastMaintenance'), value: widget.machine.lastMaintenance, caption: strings.get('recentRecord'), icon: Icons.event_available_outlined, color: SteelColors.primary),
                MetricCard(label: strings.get('nextMaintenance'), value: strings.translate(widget.machine.nextMaintenance), caption: strings.get('preventiveForecast'), icon: Icons.event_repeat_outlined, color: SteelColors.primary),
                MetricCard(label: strings.get('situation'), value: strings.translate(widget.machine.maintenanceStatus), caption: strings.get('status'), icon: Icons.health_and_safety_outlined, color: SteelColors.warning),
                MetricCard(label: strings.get('cycles'), value: '${widget.machine.cycles}', caption: strings.get('reviewBasis'), icon: Icons.sync_rounded, color: SteelColors.success),
              ]);
            }),
            const SizedBox(height: 14),
            SectionCard(child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.handyman_outlined, color: SteelColors.primary)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('maintenanceCenter'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 3), Text(strings.get('maintenancePermission'), style: const TextStyle(color: SteelColors.muted, fontSize: 12))])), if (_busy) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))])),
            const SizedBox(height: 14),
            Text(strings.get('maintenanceHistory'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              SectionCard(child: Column(children: [Text('${snapshot.error}'), const SizedBox(height: 10), OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: Text(strings.get('retry')))]))
            else if ((snapshot.data ?? const []).isEmpty)
              SectionCard(child: Padding(padding: const EdgeInsets.all(20), child: Text(strings.get('noMaintenance'))))
            else
              ...snapshot.data!.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: SteelColors.warning.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.build_outlined, color: SteelColors.warning)),
                          const SizedBox(width: 13),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(strings.translate(item.type), style: const TextStyle(fontWeight: FontWeight.w800))), _MaintenanceId(id: item.id)]), const SizedBox(height: 5), Text(item.description), const SizedBox(height: 9), Wrap(spacing: 14, runSpacing: 5, children: [Text('${strings.get('responsibleTechnician')}: ${item.technician}', style: const TextStyle(color: SteelColors.muted, fontSize: 12)), Text('${item.date} • ${item.time}', style: const TextStyle(color: SteelColors.muted, fontSize: 12)), if (item.cycles != null) Text('${strings.get('cycles')}: ${item.cycles}', style: const TextStyle(color: SteelColors.muted, fontSize: 12))])])),
                          if (_admin) IconButton(tooltip: strings.get('remove'), onPressed: _busy ? null : () => _remove(item), color: SteelColors.danger, icon: const Icon(Icons.delete_outline_rounded)),
                        ],
                      ),
                    ),
                  )),
          ],
        )),
      );
  }

  Future<void> _openForm() async {
    final result = await showDialog<_MaintenanceFormResult>(
      context: context,
      builder: (_) => _MaintenanceDialog(technician: widget.controller.session?.user.name ?? ''),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.controller.machinesApi.createMaintenance(machineId: widget.machine.id, type: result.type, technician: result.technician, description: result.description);
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).get('maintenanceSuccess')), backgroundColor: SteelColors.success));
    } on ApiException catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message), backgroundColor: SteelColors.danger));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(MaintenanceRecord item) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(icon: const Icon(Icons.warning_amber_rounded, color: SteelColors.warning, size: 38), title: Text('${strings.get('remove')} #${item.id}?'), content: Text(item.description), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(strings.get('cancel'))), FilledButton(style: FilledButton.styleFrom(backgroundColor: SteelColors.danger), onPressed: () => Navigator.pop(dialogContext, true), child: Text(strings.get('remove')))])) ?? false;
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.controller.machinesApi.removeMaintenance(widget.machine.id, item.id);
      await _refresh();
    } on ApiException catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message), backgroundColor: SteelColors.danger));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MaintenanceId extends StatelessWidget { const _MaintenanceId({required this.id}); final int id; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(99)), child: Text('#$id', style: const TextStyle(color: SteelColors.primary, fontSize: 10, fontWeight: FontWeight.w800))); }

class _MaintenanceDialog extends StatefulWidget {
  const _MaintenanceDialog({required this.technician});
  final String technician;
  @override State<_MaintenanceDialog> createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends State<_MaintenanceDialog> {
  final key = GlobalKey<FormState>();
  late final TextEditingController technician;
  final description = TextEditingController();
  String type = 'Preventiva';

  @override void initState() { super.initState(); technician = TextEditingController(text: widget.technician); }
  @override void dispose() { technician.dispose(); description.dispose(); super.dispose(); }

  String? requiredField(String? value) => value?.trim().isNotEmpty == true ? null : AppStrings.of(context).get('requiredField');

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      icon: const Icon(Icons.handyman_outlined, color: SteelColors.primary, size: 38),
      title: Text(strings.get('maintenanceRegister')),
      content: SizedBox(width: 520, child: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: type, decoration: InputDecoration(labelText: strings.get('maintenanceType')), items: const ['Preventiva', 'Corretiva', 'Preditiva', 'Inspeção', 'Lubrificação'].map((value) => DropdownMenuItem(value: value, child: Text(strings.translate(value)))).toList(), onChanged: (value) => type = value ?? type),
        const SizedBox(height: 12),
        TextFormField(controller: technician, decoration: InputDecoration(labelText: strings.get('responsibleTechnician'), prefixIcon: const Icon(Icons.engineering_outlined)), validator: requiredField),
        const SizedBox(height: 12),
        TextFormField(controller: description, maxLines: 4, decoration: InputDecoration(labelText: strings.get('serviceDescription'), alignLabelWithHint: true, prefixIcon: const Icon(Icons.notes_rounded)), validator: requiredField),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.get('cancel'))), FilledButton.icon(onPressed: () { if (!key.currentState!.validate()) return; Navigator.pop(context, _MaintenanceFormResult(type: type, technician: technician.text.trim(), description: description.text.trim())); }, icon: const Icon(Icons.save_outlined), label: Text(strings.get('save')))],
    );
  }
}

class _MaintenanceFormResult { const _MaintenanceFormResult({required this.type, required this.technician, required this.description}); final String type, technician, description; }

class LogsSection extends StatelessWidget {
  const LogsSection({required this.machine, super.key});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return _EventList(
        title: strings.get('machineLogs'),
        subtitle: '${strings.get('recordsOnly')} • ${machine.name}',
        empty: strings.get('noLogs'),
        items: machine.logs.map((text) => _EventItem(Icons.receipt_long_outlined, text, SteelColors.primary)).toList(),
      );
  }
}

class AlertsSection extends StatelessWidget {
  const AlertsSection({required this.machine, super.key});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return _EventList(
        title: strings.get('machineAlerts'),
        subtitle: '${strings.get('eventsOnly')} • ${machine.name}',
        empty: strings.get('noAlerts'),
        items: machine.alerts.map((alert) => _EventItem(Icons.warning_amber_rounded, alert.message, alert.type.toLowerCase().contains('crít') ? SteelColors.danger : SteelColors.warning, date: alert.createdAt)).toList(),
      );
  }
}

class _EventItem {
  const _EventItem(this.icon, this.text, this.color, {this.date});
  final IconData icon;
  final String text;
  final Color color;
  final DateTime? date;
}

class _EventList extends StatelessWidget {
  const _EventList({required this.title, required this.subtitle, required this.empty, required this.items});
  final String title;
  final String subtitle;
  final String empty;
  final List<_EventItem> items;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: SteelColors.muted)),
          const SizedBox(height: 18),
          if (items.isEmpty)
            SectionCard(child: Padding(padding: const EdgeInsets.all(20), child: Text(empty)))
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SectionCard(
                    child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: item.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(item.icon, color: item.color)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.text, style: const TextStyle(fontWeight: FontWeight.w600)), if (item.date != null) Text(DateFormat('dd/MM/yyyy HH:mm').format(item.date!.toLocal()), style: const TextStyle(color: SteelColors.muted, fontSize: 11))]))]),
                  ),
                )),
        ],
      );
}

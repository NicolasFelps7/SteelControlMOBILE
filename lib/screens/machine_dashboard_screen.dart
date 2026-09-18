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
              if (!machine.is3DPrinter)
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
              if (machine.hasIndustrialHmi && !machine.is3DPrinter)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                  sliver: SliverToBoxAdapter(
                    child: IndustrialHmiPanel(controller: controller, machine: machine),
                  ),
                ),
              if (machine.is3DPrinter)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                  sliver: SliverToBoxAdapter(
                    child: _Printer3DDashboard(
                      controller: controller,
                      machine: machine,
                    ),
                  ),
                ),
              if (!machine.is3DPrinter)
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
              if (machine.simulation && !machine.is3DPrinter)
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final muted = dark ? SteelColors.mutedDark : SteelColors.muted;
    final online = machine.isOnline;
    final strings = AppStrings.of(context);
    final border = scheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SteelColors.industrialAccent.withValues(alpha: .10),
              border: Border.all(
                color: SteelColors.industrialAccent.withValues(alpha: .24),
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              machine.isDobot
                  ? Icons.precision_manufacturing_rounded
                  : machine.is3DPrinter
                      ? Icons.view_in_ar_rounded
                      : Icons.factory_outlined,
              color: SteelColors.industrialAccent,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.get(
                    machine.isDobot ? 'robotCellPanel' : 'machineExclusivePanel',
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: SteelColors.industrialAccent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .65,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  machine.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${machine.controller ?? machine.model} • ${machine.protocol ?? machine.sector}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: online
                  ? SteelColors.success.withValues(alpha: .08)
                  : SteelColors.danger.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: online
                    ? SteelColors.success.withValues(alpha: .28)
                    : SteelColors.danger.withValues(alpha: .24),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  color: online ? SteelColors.success : SteelColors.danger,
                  size: 9,
                ),
                const SizedBox(width: 7),
                Text(
                  online ? strings.get('online') : strings.get('waitingTelemetry'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: online ? SteelColors.success : SteelColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Printer3DDashboard extends StatelessWidget {
  const _Printer3DDashboard({required this.controller, required this.machine});
  final AppController controller;
  final Machine machine;

  dynamic _first(List<dynamic> values) {
    for (final value in values) {
      if (value != null && '$value'.trim().isNotEmpty) return value;
    }
    return null;
  }

  double? _number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
  Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
  String _text(dynamic value) => value == null || '$value'.trim().isEmpty ? '--' : '$value';
  String _temp(dynamic value) { final n = _number(value); return n == null ? '--' : '${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)} °C'; }
  String _percent(dynamic value) { final n = _number(value); if (n == null) return '--'; final p = n >= 0 && n <= 1 ? n * 100 : n; return '${p.clamp(0, 100).round()}%'; }
  String _duration(dynamic value) { final n = _number(value); if (n == null || n < 0) return '--'; final seconds = n.round().clamp(0, 1 << 30); final h = seconds ~/ 3600; final m = (seconds % 3600) ~/ 60; final sec = seconds % 60; return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m ${sec.toString().padLeft(2, '0')}s'; }
  String _axis(dynamic value) { final n = _number(value); return n == null ? '--' : n.toStringAsFixed(1); }
  String _time(dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return '--';
    final parsed = DateTime.tryParse('$value');
    return parsed == null ? '$value' : DateFormat('HH:mm:ss').format(parsed.toLocal());
  }
  String _eta(dynamic explicitValue, dynamic remainingValue) {
    if (explicitValue != null && '$explicitValue'.trim().isNotEmpty) {
      return _time(explicitValue);
    }
    final seconds = _number(remainingValue);
    if (seconds == null || seconds < 0) return '--';
    return DateFormat('HH:mm').format(
      DateTime.now().add(Duration(seconds: seconds.round())),
    );
  }

  String _mode(String technology) {
    final value = technology.toLowerCase();
    if (value.contains('sla') || value.contains('msla') || value.contains('dlp') || value.contains('resin') || value.contains('resina') || value.contains('lcd')) return 'resin';
    if (value.contains('sls') || value.contains('powder') || value.contains('pó')) return 'powder';
    if (value.contains('fdm') || value.contains('fff') || value.contains('filament') || value.contains('filamento') || value.contains('marlin') || value.contains('klipper')) return 'fdm';
    return 'universal';
  }

  ({String primary, String bed, String chamber, String mode}) _labels(String mode) {
    return switch (mode) {
      'resin' => (primary: 'Resina / processo', bed: 'Plataforma', chamber: 'Câmara / ambiente', mode: 'Resina • SLA/MSLA/DLP'),
      'powder' => (primary: 'Leito / processo', bed: 'Plataforma', chamber: 'Câmara', mode: 'Pó • SLS'),
      'fdm' => (primary: 'Bico / extrusor', bed: 'Mesa aquecida', chamber: 'Câmara', mode: 'Filamento • FDM/FFF'),
      _ => (primary: 'Processo térmico', bed: 'Plataforma', chamber: 'Câmara / material', mode: 'Tecnologia universal'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final extras = machine.extraData;
    final p = _map(extras['impressora3d'] ?? extras['printer3d'] ?? extras['printer']);
    final nozzle = _map(p['nozzle'] ?? p['extruder']);
    final bed = _map(p['bed'] ?? p['buildPlate']);
    final chamber = _map(p['chamber'] ?? (p['resin'] is Map ? p['resin'] : null));
    final processTemperature = _map(p['processTemperature'] ?? p['processTemp']);
    final job = _map(p['job'] ?? p['print']);
    final layer = _map(p['layer'] ?? job['layer']);
    final motion = _map(p['motion'] ?? p['position'] ?? p['axes']);
    final position = _map(motion['position'] ?? motion['axes'] ?? motion);
    final process = _map(p['process'] ?? p['parameters']);
    final materialInfo = _map(p['materialInfo'] ?? p['materialData']);
    final safety = _map(p['safety'] ?? p['interlocks']);
    final capabilities = _map(p['capabilities'] ?? p['features']);
    final camera = _map(p['camera'] ?? p['webcam'] ?? p['video']);
    final rawCameraUrl = _first([camera['streamUrl'], camera['stream'], camera['snapshotUrl'], camera['snapshot'], camera['imageUrl'], p['cameraStreamUrl'], p['cameraSnapshotUrl']]);
    final parsedCameraUri = rawCameraUrl == null ? null : Uri.tryParse('$rawCameraUrl');
    final cameraUrl = parsedCameraUri != null && (parsedCameraUri.scheme == 'http' || parsedCameraUri.scheme == 'https') ? parsedCameraUri.toString() : null;

    final technology = '${_first([p['technology'], p['tecnologia'], machine.integrationMeta['impressora3d'] is Map ? (machine.integrationMeta['impressora3d'] as Map)['technology'] : null, machine.type]) ?? 'Universal'}';
    final mode = _mode(technology);
    final labels = _labels(mode);
    final ecosystem = '${_first([p['ecosystem'], p['ecossistema'], p['platform'], machine.protocol]) ?? 'Universal'}';
    // O status cadastral "Ligada" não deve ser usado como prova de conexão.
    // Sem telemetria real, o painel inteiro comunica o mesmo estado offline.
    final state = machine.isOnline
        ? '${_first([p['state'], p['status'], job['state'], machine.status]) ?? 'Aguardando dados'}'.replaceAll('_', ' ')
        : 'Aguardando telemetria';
    final file = '${_first([p['filename'], p['file'], job['filename'], job['file']]) ?? 'Sem arquivo'}';
    final progressRaw = _first([p['progress'], job['progress']]);
    final progressNumber = _number(progressRaw);
    final progress = ((progressNumber ?? 0) >= 0 && (progressNumber ?? 0) <= 1 ? (progressNumber ?? 0) * 100 : (progressNumber ?? 0)).clamp(0, 100).toDouble();

    final primaryCurrent = mode == 'resin'
        ? _first([processTemperature['current'], processTemperature['actual'], p['resinTemperature'], chamber['current'], chamber['actual']])
        : mode == 'powder'
            ? _first([processTemperature['current'], processTemperature['actual'], p['powderTemperature'], chamber['current']])
            : _first([nozzle['current'], nozzle['actual'], nozzle['temperature'], p['nozzleTemp'], p['hotendTemp']]);
    final primaryTarget = mode == 'resin'
        ? _first([processTemperature['target'], processTemperature['setpoint'], p['resinTarget'], chamber['target']])
        : mode == 'powder'
            ? _first([processTemperature['target'], processTemperature['setpoint'], p['powderTarget'], chamber['target']])
            : _first([nozzle['target'], nozzle['setpoint'], p['nozzleTarget'], p['hotendTarget']]);
    final bedCurrent = _first([
      bed['current'],
      bed['actual'],
      bed['temperature'],
      p['bedTemp'],
    ]);
    final bedTarget = _first([bed['target'], bed['setpoint'], p['bedTarget']]);
    final chamberCurrent = _first([
      chamber['current'],
      chamber['actual'],
      chamber['temperature'],
      p['chamberTemp'],
      p['ambientTemp'],
    ]);
    final chamberTarget = _first([
      chamber['target'],
      chamber['setpoint'],
      p['chamberTarget'],
    ]);

    final flowLabel = mode == 'resin' ? 'Elevação / lift' : mode == 'powder' ? 'Alimentação de pó' : 'Fluxo';
    final flowValue = mode == 'resin'
        ? (_number(_first([p['liftSpeed'], process['liftSpeed']])) == null ? '--' : '${_number(_first([p['liftSpeed'], process['liftSpeed']]))!.toStringAsFixed(1)} mm/s')
        : mode == 'powder'
            ? _percent(_first([p['powderFeedPercent'], p['powderFeed'], process['powderFeedPercent']]))
            : _percent(_first([p['flowPercent'], p['flow'], process['flowPercent']]));
    final processLabel = mode == 'resin' ? 'Exposição / UV' : mode == 'powder' ? 'Potência laser' : 'Potência / carga';
    final exposure = _number(_first([p['exposureSeconds'], p['exposureTime'], process['exposureSeconds'], process['exposureTime']]));
    final processValue = mode == 'resin'
        ? exposure != null ? '${exposure.toStringAsFixed(exposure % 1 == 0 ? 0 : 1)} s' : _percent(_first([p['uvPowerPercent'], p['uvPower'], process['uvPowerPercent']]))
        : mode == 'powder'
            ? _percent(_first([p['laserPowerPercent'], p['laserPower'], process['laserPowerPercent']]))
            : _percent(_first([p['powerPercent'], p['power'], process['powerPercent']]));

    final material = _first([p['material'] is String ? p['material'] : null, p['filament'], p['resin'] is String ? p['resin'] : null, job['material'], materialInfo['type'], materialInfo['name']]);
    final materialUsed = _first([p['materialUsed'], p['filamentUsed'], p['resinUsed'], job['materialUsed'], materialInfo['used']]);
    final materialRemaining = _first([p['materialRemaining'], p['filamentRemaining'], p['resinRemaining'], materialInfo['remaining'], materialInfo['remainingPercent']]);
    final lastUpdate = _first([
      p['timestamp'],
      p['updatedAt'],
      p['lastUpdate'],
      extras['timestamp'],
    ]);
    final printerMeta = _map(machine.integrationMeta['impressora3d']);
    final remoteControlEnabled = printerMeta['remoteControlEnabled'] == true;
    final alarm = _first([p['alarm'], p['error'], p['message'], safety['alarm'], safety['error']]);
    final doorOpen = _first([p['doorOpen'], safety['doorOpen']]) == true || '${_first([p['door'], safety['door']])}'.toLowerCase() == 'open';
    final emergency = _first([p['emergency'], p['emergencyStop'], safety['emergency'], safety['emergencyStop']]) == true;
    final safetyText = emergency ? 'Emergência ativa' : doorOpen ? 'Porta / tampa aberta' : alarm != null ? '$alarm' : 'Nenhum alarme informado';

    final axisItems = <({String label, String value})>[
      (label: 'X', value: _axis(_first([position['x'], p['x'], p['axisX']]))),
      (label: 'Y', value: _axis(_first([position['y'], p['y'], p['axisY']]))),
      (label: 'Z', value: _axis(_first([position['z'], p['z'], p['axisZ']]))),
      (label: 'E', value: _axis(_first([position['e'], position['extruder'], p['e'], p['axisE']]))),
    ];

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final border = scheme.outlineVariant;
    final muted = dark ? SteelColors.mutedDark : SteelColors.muted;
    final accent = SteelColors.industrialAccent;
    final statusColor = machine.isOnline ? SteelColors.success : SteelColors.danger;
    final printing = state.toLowerCase().contains('print') || state.toLowerCase().contains('imprim');

    Widget cameraPanel() {
      return _HmiPanel(
        title: 'VISÃO REMOTA',
        subtitle: cameraUrl == null ? 'Câmera não informada pelo Edge' : 'Câmera da impressão',
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF0C1114) : const Color(0xFFF0F3F4),
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: cameraUrl == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_off_outlined,
                          color: muted,
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sem câmera configurada',
                          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  )
                : Image.network(
                    cameraUrl,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.broken_image_outlined,
                            color: SteelColors.warning,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Câmera indisponível',
                            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      );
    }

    Widget jobPanel() {
      final remaining = _first([
        p['remainingSeconds'],
        p['remaining'],
        job['remainingSeconds'],
      ]);
      final jobItems = <({String label, String value})>[
        (
          label: 'Camada',
          value:
              '${_text(_first([layer['current'], layer['number'], p['currentLayer']]))} / ${_text(_first([layer['total'], p['totalLayers']]))}'
        ),
        (
          label: 'Decorrido',
          value: _duration(_first([p['elapsedSeconds'], p['elapsed'], job['elapsedSeconds']]))
        ),
        (
          label: 'Restante',
          value: _duration(remaining)
        ),
        (
          label: 'Conclusão',
          value: _eta(
            _first([p['eta'], p['estimatedCompletion'], job['eta']]),
            remaining,
          )
        ),
      ];

      return _HmiPanel(
        title: 'TRABALHO ATUAL',
        subtitle: file,
        trailing: Text(
          _percent(progress),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 9,
                backgroundColor:
                    dark ? const Color(0xFF0F1518) : const Color(0xFFE3E8EA),
                color: accent,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth >= 620 ? 4 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: count,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: count == 4 ? 2.15 : 2.0,
                  children: jobItems
                      .map((item) => _HmiValueBox(label: item.label, value: item.value))
                      .toList(),
                );
              },
            ),
          ],
        ),
      );
    }

    final thermalPanel = _HmiPanel(
      title: 'PROCESSO TÉRMICO',
      subtitle: 'Temperaturas específicas da impressora',
      child: Column(
        children: [
          _HmiThermal(
            label: labels.primary,
            current: _temp(primaryCurrent),
            target: 'Alvo: ${_temp(primaryTarget)}',
            icon: Icons.thermostat_rounded,
          ),
          const SizedBox(height: 8),
          _HmiThermal(
            label: labels.bed,
            current: _temp(bedCurrent),
            target: 'Alvo: ${_temp(bedTarget)}',
            icon: Icons.grid_4x4_rounded,
          ),
          const SizedBox(height: 8),
          _HmiThermal(
            label: labels.chamber,
            current: _temp(chamberCurrent),
            target: 'Alvo: ${_temp(chamberTarget)}',
            icon: Icons.inventory_2_outlined,
          ),
        ],
      ),
    );

    final parametersPanel = _HmiPanel(
      title: 'PARÂMETROS DE IMPRESSÃO',
      subtitle: 'Processo em tempo real',
      child: LayoutBuilder(
        builder: (context, c) {
          final count = c.maxWidth >= 520 ? 3 : 2;
          final items = <({IconData icon, String label, String value})>[
            (
              icon: Icons.speed_rounded,
              label: 'Velocidade',
              value: _percent(_first([
                p['speedPercent'],
                p['speed'],
                process['speedPercent'],
              ])),
            ),
            (
              icon: Icons.air_rounded,
              label: 'Ventoinha',
              value: _percent(_first([
                p['fanPercent'],
                p['fan'],
                process['fanPercent'],
              ])),
            ),
            (icon: Icons.water_drop_outlined, label: flowLabel, value: flowValue),
            (icon: Icons.bolt_rounded, label: processLabel, value: processValue),
            (icon: Icons.category_outlined, label: 'Material', value: _text(material)),
            (
              icon: Icons.inventory_2_outlined,
              label: 'Restante',
              value: _text(materialRemaining),
            ),
          ];
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: count,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: count == 3 ? 1.7 : 1.65,
            children: items
                .map(
                  (item) => _HmiProcessValue(
                    icon: item.icon,
                    label: item.label,
                    value: item.value,
                  ),
                )
                .toList(),
          );
        },
      ),
    );

    final trendPanel = _HmiPanel(
      title: 'HISTÓRICO LOCAL',
      subtitle: 'Tendência térmica',
      child: _PrinterThermalTrend(
        primary: _number(primaryCurrent),
        bed: _number(bedCurrent),
        chamber: _number(chamberCurrent),
        primaryLabel: labels.primary,
        bedLabel: labels.bed,
        chamberLabel: labels.chamber,
      ),
    );

    final machinePanel = _HmiPanel(
      title: 'IHM DA MÁQUINA',
      subtitle: labels.mode,
      child: _PrinterMimic(state: state, printing: printing),
    );

    final axesPanel = _HmiPanel(
      title: 'POSIÇÃO DOS EIXOS',
      subtitle: 'Coordenadas recebidas',
      child: Row(
        children: axisItems
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _HmiAxis(label: item.label, value: item.value),
                ),
              ),
            )
            .toList(),
      ),
    );

    final controlPanel = _PrinterControlPanel(
      controller: controller,
      machine: machine,
      capabilities: capabilities,
      enabled: remoteControlEnabled && machine.isOnline && !machine.simulation,
    );

    final connectionPanel = _HmiPanel(
      title: 'CONEXÃO',
      subtitle: 'Integração da impressora',
      child: Column(
        children: [
          _HmiInfoRow(label: 'Ecossistema', value: ecosystem),
          _HmiInfoRow(
            label: 'Fonte',
            value: _text(_first([p['source'], p['origin'], machine.protocol])),
          ),
          _HmiInfoRow(
            label: 'Firmware',
            value: _text(_first([p['firmware'], p['firmwareVersion']])),
          ),
          _HmiInfoRow(
            label: 'Host / IP',
            value: _text(_first([p['host'], p['hostname'], p['ip']])),
          ),
          _HmiInfoRow(label: 'Última leitura', value: _time(lastUpdate)),
          _HmiInfoRow(label: 'Material usado', value: _text(materialUsed)),
        ],
      ),
    );

    final safetyPanel = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emergency
            ? SteelColors.danger.withValues(alpha: .08)
            : doorOpen || alarm != null
                ? SteelColors.warning.withValues(alpha: .08)
                : SteelColors.success.withValues(alpha: .08),
        border: Border.all(
          color: emergency
              ? SteelColors.danger.withValues(alpha: .40)
              : doorOpen || alarm != null
                  ? SteelColors.warning.withValues(alpha: .40)
                  : SteelColors.success.withValues(alpha: .35),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 22,
            color: emergency
                ? SteelColors.danger
                : doorOpen || alarm != null
                    ? SteelColors.warning
                    : SteelColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SEGURANÇA / INTERTRAVAMENTO',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .55,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  safetyText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget headerIdentity() => Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                border: Border.all(color: accent.withValues(alpha: .28)),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.view_in_ar_rounded,
                color: SteelColors.industrialAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IHM • PRODUÇÃO ADITIVA',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Impressora 3D',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$technology • $ecosystem • IHM dedicada',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ],
        );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x120F1418),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final badge = _HmiBadge(
                  icon: Icons.circle,
                  label: state,
                  color: statusColor,
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      headerIdentity(),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: badge),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: headerIdentity()),
                    const SizedBox(width: 14),
                    badge,
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 820) {
                      return Column(
                        children: [
                          jobPanel(),
                          const SizedBox(height: 12),
                          cameraPanel(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: jobPanel()),
                        const SizedBox(width: 12),
                        Expanded(flex: 4, child: cameraPanel()),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 820) {
                      return Column(
                        children: [
                          thermalPanel,
                          const SizedBox(height: 12),
                          parametersPanel,
                          const SizedBox(height: 12),
                          trendPanel,
                          const SizedBox(height: 12),
                          machinePanel,
                          const SizedBox(height: 12),
                          axesPanel,
                          const SizedBox(height: 12),
                          controlPanel,
                          const SizedBox(height: 12),
                          connectionPanel,
                          const SizedBox(height: 12),
                          safetyPanel,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              thermalPanel,
                              const SizedBox(height: 12),
                              parametersPanel,
                              const SizedBox(height: 12),
                              trendPanel,
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              machinePanel,
                              const SizedBox(height: 12),
                              axesPanel,
                              const SizedBox(height: 12),
                              controlPanel,
                              const SizedBox(height: 12),
                              connectionPanel,
                              const SizedBox(height: 12),
                              safetyPanel,
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: SteelColors.industrialAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'IHM exclusiva para impressoras 3D. Adapta-se a FDM/FFF, SLA/MSLA/DLP, SLS e controladores proprietários. Campos sem telemetria permanecem como “--”.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinterThermalTrend extends StatefulWidget {
  const _PrinterThermalTrend({
    required this.primary,
    required this.bed,
    required this.chamber,
    required this.primaryLabel,
    required this.bedLabel,
    required this.chamberLabel,
  });

  final double? primary;
  final double? bed;
  final double? chamber;
  final String primaryLabel;
  final String bedLabel;
  final String chamberLabel;

  @override
  State<_PrinterThermalTrend> createState() => _PrinterThermalTrendState();
}

class _PrinterThermalTrendState extends State<_PrinterThermalTrend> {
  final List<({double? primary, double? bed, double? chamber})> _samples = [];

  @override
  void initState() {
    super.initState();
    _record();
  }

  @override
  void didUpdateWidget(covariant _PrinterThermalTrend oldWidget) {
    super.didUpdateWidget(oldWidget);
    _record();
  }

  void _record() {
    final sample = (
      primary: widget.primary,
      bed: widget.bed,
      chamber: widget.chamber,
    );
    if (sample.primary == null && sample.bed == null && sample.chamber == null) {
      return;
    }
    if (_samples.isNotEmpty && _samples.last == sample) return;
    _samples.add(sample);
    if (_samples.length > 42) _samples.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? SteelColors.mutedDark
        : SteelColors.muted;
    final values = _samples
        .expand((sample) => [sample.primary, sample.bed, sample.chamber])
        .whereType<double>()
        .toList();

    if (values.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Text(
            'Aguardando leituras de temperatura',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      );
    }

    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final padding = math.max(5.0, (maximum - minimum) * .12);
    final chartMin = math.max(0.0, minimum - padding);
    final chartMax = math.max(chartMin + 10, maximum + padding);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _TrendLegend(color: SteelColors.industrialAccent, label: widget.primaryLabel),
            _TrendLegend(color: const Color(0xFF2563EB), label: widget.bedLabel),
            _TrendLegend(color: SteelColors.success, label: widget.chamberLabel),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 160,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 42,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${chartMax.round()} °C', style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                    Text('${chartMin.round()} °C', style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                  ],
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _PrinterTrendPainter(
                    samples: _samples,
                    minimum: chartMin,
                    maximum: chartMax,
                    gridColor: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _PrinterTrendPainter extends CustomPainter {
  const _PrinterTrendPainter({
    required this.samples,
    required this.minimum,
    required this.maximum,
    required this.gridColor,
  });

  final List<({double? primary, double? bed, double? chamber})> samples;
  final double minimum;
  final double maximum;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = gridColor.withValues(alpha: .75)..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = size.height * index / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    _drawLine(canvas, size, (sample) => sample.primary, SteelColors.industrialAccent);
    _drawLine(canvas, size, (sample) => sample.bed, const Color(0xFF2563EB));
    _drawLine(canvas, size, (sample) => sample.chamber, SteelColors.success);
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    double? Function(({double? primary, double? bed, double? chamber})) select,
    Color color,
  ) {
    final path = Path();
    var started = false;
    for (var index = 0; index < samples.length; index++) {
      final value = select(samples[index]);
      if (value == null) continue;
      final x = samples.length == 1 ? size.width / 2 : size.width * index / (samples.length - 1);
      final y = size.height - ((value - minimum) / (maximum - minimum)) * size.height;
      if (!started) {
        path.moveTo(x, y.clamp(0, size.height).toDouble());
        started = true;
      } else {
        path.lineTo(x, y.clamp(0, size.height).toDouble());
      }
    }
    if (!started) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.25
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PrinterTrendPainter oldDelegate) => true;
}

class _PrinterControlPanel extends StatefulWidget {
  const _PrinterControlPanel({
    required this.controller,
    required this.machine,
    required this.capabilities,
    required this.enabled,
  });

  final AppController controller;
  final Machine machine;
  final Map<String, dynamic> capabilities;
  final bool enabled;

  @override
  State<_PrinterControlPanel> createState() => _PrinterControlPanelState();
}

class _PrinterControlPanelState extends State<_PrinterControlPanel> {
  String? _busyCommand;

  Future<void> _send(String command, String label, {bool dangerous = false}) async {
    if (!widget.enabled || _busyCommand != null) return;
    if (dangerous) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar comando'),
          content: Text('Deseja enviar “$label” para a impressora 3D?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busyCommand = command);
    try {
      await widget.controller.machinesApi.sendPrinter3DCommand(widget.machine.id, command);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comando “$label” enviado com segurança.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível enviar “$label”: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyCommand = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commands = <({String command, String label, String capability, IconData icon, bool danger})>[
      (command: 'PRINTER3D_PAUSE', label: 'Pausar', capability: 'pause', icon: Icons.pause_rounded, danger: false),
      (command: 'PRINTER3D_RESUME', label: 'Continuar', capability: 'resume', icon: Icons.play_arrow_rounded, danger: false),
      (command: 'PRINTER3D_HOME', label: 'Home', capability: 'home', icon: Icons.home_outlined, danger: true),
      (command: 'PRINTER3D_LIGHT_ON', label: 'Luz ON', capability: 'light', icon: Icons.lightbulb_outline_rounded, danger: false),
      (command: 'PRINTER3D_LIGHT_OFF', label: 'Luz OFF', capability: 'light', icon: Icons.lightbulb_outline, danger: false),
      (command: 'PRINTER3D_CANCEL', label: 'Cancelar', capability: 'cancel', icon: Icons.block_rounded, danger: true),
    ];
    return _HmiPanel(
      title: 'CONTROLE DO TRABALHO',
      subtitle: widget.enabled ? 'Controle remoto habilitado' : 'Somente monitoramento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: commands.map((item) {
                  final supported = widget.capabilities[item.capability] != false;
                  final loading = _busyCommand == item.command;
                  return SizedBox(
                    width: width,
                    child: OutlinedButton.icon(
                      onPressed: widget.enabled && supported && _busyCommand == null
                          ? () => _send(item.command, item.label, dangerous: item.danger)
                          : null,
                      icon: loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(item.icon, color: item.danger ? SteelColors.danger : null),
                      label: Text(item.label),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 9),
          Text(
            widget.enabled
                ? 'Os comandos são enviados ao Edge e executados apenas quando o recurso é suportado.'
                : 'Habilite o controle remoto no cadastro e mantenha a impressora online para liberar os comandos.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? SteelColors.mutedDark
                      : SteelColors.muted,
                ),
          ),
        ],
      ),
    );
  }
}

class _HmiBadge extends StatelessWidget {
  const _HmiBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = theme.colorScheme.outlineVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: dark ? Colors.white : SteelColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HmiPanel extends StatelessWidget {
  const _HmiPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? SteelColors.mutedDark
        : SteelColors.muted;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .55,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _HmiValueBox extends StatelessWidget {
  const _HmiValueBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? SteelColors.mutedDark
        : SteelColors.muted;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HmiThermal extends StatelessWidget {
  const _HmiThermal({
    required this.label,
    required this.current,
    required this.target,
    required this.icon,
  });

  final String label;
  final String current;
  final String target;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? SteelColors.mutedDark
        : SteelColors.muted;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SteelColors.industrialAccent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: SteelColors.industrialAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 1),
                Text(
                  current,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  target,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HmiProcessValue extends StatelessWidget {
  const _HmiProcessValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? SteelColors.mutedDark
        : SteelColors.muted;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: SteelColors.industrialAccent,
            size: 18,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HmiAxis extends StatelessWidget {
  const _HmiAxis({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? SteelColors.mutedDark
        : SteelColors.muted;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: SteelColors.industrialAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'mm',
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _HmiInfoRow extends StatelessWidget {
  const _HmiInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? SteelColors.mutedDark
        : SteelColors.muted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinterMimic extends StatelessWidget {
  const _PrinterMimic({required this.state, required this.printing});

  final String state;
  final bool printing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = theme.colorScheme.outlineVariant;
    final muted = dark ? SteelColors.mutedDark : SteelColors.muted;

    return Column(
      children: [
        Container(
          height: 155,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF0D1316) : const Color(0xFFF0F3F4),
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 14,
                right: 14,
                top: 33,
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF53626A)
                        : const Color(0xFFAAB5BA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: 30,
                right: 30,
                bottom: 24,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF526067)
                        : const Color(0xFFADB7BC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                left: 70,
                right: 70,
                bottom: 34,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    4,
                    (_) => Container(
                      height: 5,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color: SteelColors.industrialAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: printing ? 115 : 82,
                top: 40,
                child: Container(
                  width: 34,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: SteelColors.industrialAccent,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Text(
                state,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.circle,
              color: printing ? SteelColors.industrialAccent : SteelColors.success,
              size: 8,
            ),
            const SizedBox(width: 2),
            Text(
              printing ? 'Em impressão' : 'Pronta',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ],
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
                              ?.copyWith(fontWeight: FontWeight.w700),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                fontWeight: FontWeight.w700,
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
                fontWeight: FontWeight.w700,
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
            Row(children: [const Icon(Icons.science_outlined, color: SteelColors.primary), const SizedBox(width: 10), Text(strings.get('demoMode'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))]),
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
    final root = machine.extraData;
    final nestedDobot = root['dobot'];
    final source = nestedDobot is Map ? nestedDobot : root;
    final value = source[group];
    if (value is! Map) return null;
    return value[key] ?? value[key.toUpperCase()];
  }

  String _dobotNumber(dynamic value) {
    if (value == null) return '--';
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number == null ? '$value' : number.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final axes = ['X', 'Y', 'Z', 'R'];
    final joints = ['J1', 'J2', 'J3', 'J4'];
    final strings = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final pose = _DobotValuesCard(
              icon: Icons.my_location_rounded,
              title: strings.get('endEffectorPosition'),
              labels: axes,
              values: axes.map((item) => _dobotNumber(_extra('pose', item.toLowerCase()))).toList(),
              unit: ['mm', 'mm', 'mm', '°'],
            );
            final joint = _DobotValuesCard(
              icon: Icons.hub_outlined,
              title: strings.get('jointAngles'),
              labels: joints,
              values: joints.map((item) => _dobotNumber(_extra('joints', item.toLowerCase()))).toList(),
              unit: const ['°', '°', '°', '°'],
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: pose), const SizedBox(width: 12), Expanded(child: joint)],
              );
            }
            return Column(children: [pose, const SizedBox(height: 12), joint]);
          },
        ),
        const SizedBox(height: 12),
        _DobotControlModePanel(controller: controller, machine: machine),
      ],
    );
  }
}

class _DobotControlModePanel extends StatefulWidget {
  const _DobotControlModePanel({required this.controller, required this.machine});
  final AppController controller;
  final Machine machine;

  @override
  State<_DobotControlModePanel> createState() => _DobotControlModePanelState();
}

class _DobotControlModePanelState extends State<_DobotControlModePanel> {
  bool _automaticMode = false;
  bool _automaticRunning = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          accent: true,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _DobotIconBox(icon: Icons.settings_suggest_outlined),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Modo de operação', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        SizedBox(height: 2),
                        Text('Manual para ajuste e ensino; automático para o ciclo industrial.', style: TextStyle(color: SteelColors.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: _automaticRunning ? SteelColors.warning.withValues(alpha: .10) : SteelColors.success.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      _automaticRunning ? 'MANUAL INTERTRAVADO' : 'PRONTO',
                      style: TextStyle(color: _automaticRunning ? SteelColors.warning : SteelColors.success, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      active: !_automaticMode,
                      enabled: !_automaticRunning,
                      icon: Icons.pan_tool_alt_outlined,
                      title: 'MANUAL',
                      subtitle: 'PTP, HOME e efetuador',
                      onTap: () => setState(() => _automaticMode = false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeButton(
                      active: _automaticMode,
                      enabled: true,
                      icon: Icons.autorenew_rounded,
                      title: 'AUTOMÁTICO',
                      subtitle: 'Pick-and-place',
                      onTap: () => setState(() => _automaticMode = true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IndexedStack(
          index: _automaticMode ? 1 : 0,
          children: [
            _DobotManualControls(controller: widget.controller, machine: widget.machine),
            _DobotAutomaticPanel(
              controller: widget.controller,
              machine: widget.machine,
              onRunningChanged: (running) {
                if (!mounted || _automaticRunning == running) return;
                setState(() => _automaticRunning = running);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.active, required this.enabled, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final bool active;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: active
          ? SteelColors.industrialAccent.withValues(alpha: .10)
          : dark ? const Color(0xFF20282D) : const Color(0xFFF7F8F8),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedOpacity(
          opacity: enabled ? 1 : .5,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: active ? SteelColors.industrialAccent : dark ? SteelColors.borderDark : SteelColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: SteelColors.industrialAccent),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                      Text(subtitle, style: const TextStyle(color: SteelColors.muted, fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DobotManualControls extends StatelessWidget {
  const _DobotManualControls({required this.controller, required this.machine});
  final AppController controller;
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          accent: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _DobotIconBox(icon: Icons.tune_rounded),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.get('supervisedControl'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(strings.get('secureQueueCaption'), style: const TextStyle(color: SteelColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: SteelColors.success.withValues(alpha: .08), border: Border.all(color: SteelColors.success.withValues(alpha: .24)), borderRadius: BorderRadius.circular(9)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.lock_open_rounded, size: 14, color: SteelColors.success), const SizedBox(width: 6), Text(strings.get('safeQueue'), style: const TextStyle(color: SteelColors.success, fontWeight: FontWeight.w700, fontSize: 11))]),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 820 ? 4 : constraints.maxWidth >= 560 ? 3 : 2;
                  final itemWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _DobotCommandTile(width: itemWidth, label: 'HOME', command: 'DOBOT_HOME', icon: Icons.home_outlined, controller: controller, machine: machine),
                      _DobotCommandTile(width: itemWidth, label: strings.get('stop'), command: 'DOBOT_STOP', icon: Icons.stop_circle_outlined, controller: controller, machine: machine, danger: true),
                      _DobotCommandTile(width: itemWidth, label: strings.get('clearAlarms'), command: 'DOBOT_CLEAR_ALARMS', icon: Icons.notifications_off_outlined, controller: controller, machine: machine),
                      _DobotCommandTile(width: itemWidth, label: strings.get('suctionOn'), command: 'DOBOT_SUCTION_ON', icon: Icons.air_rounded, controller: controller, machine: machine),
                      _DobotCommandTile(width: itemWidth, label: strings.get('suctionOff'), command: 'DOBOT_SUCTION_OFF', icon: Icons.air_outlined, controller: controller, machine: machine),
                      _DobotCommandTile(width: itemWidth, label: strings.get('openGripper'), command: 'DOBOT_GRIPPER_OPEN', icon: Icons.open_with_rounded, controller: controller, machine: machine),
                      _DobotCommandTile(width: itemWidth, label: strings.get('closeGripper'), command: 'DOBOT_GRIPPER_CLOSE', icon: Icons.compress_rounded, controller: controller, machine: machine),
                    ],
                  );
                },
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

class _DobotAutomaticPanel extends StatefulWidget {
  const _DobotAutomaticPanel({required this.controller, required this.machine, required this.onRunningChanged});
  final AppController controller;
  final Machine machine;
  final ValueChanged<bool> onRunningChanged;

  @override
  State<_DobotAutomaticPanel> createState() => _DobotAutomaticPanelState();
}

class _DobotAutomaticPanelState extends State<_DobotAutomaticPanel> {
  final Map<String, Map<String, double>> _points = {};
  double _speed = 15;
  int _cycles = 1;
  int _completed = 0;
  bool _running = false;
  bool _paused = false;
  bool _stopRequested = false;
  String _status = 'Pronto para ensinar';
  String _step = 'Capture P0 a P4 usando a posição real do robô.';
  double _progress = 0;

  static const _labels = <String, String>{
    'P0': 'Espera',
    'P1': 'Acima da peça',
    'P2': 'Coleta',
    'P3': 'Acima do destino',
    'P4': 'Entrega',
  };

  Machine get _latestMachine => widget.controller.selectedMachine?.id == widget.machine.id ? widget.controller.selectedMachine! : widget.machine;

  Map<String, double>? _poseOf(Machine machine) {
    final root = machine.extraData;
    final nested = root['dobot'];
    final source = nested is Map ? nested : root;
    final pose = source['pose'];
    if (pose is! Map) return null;
    final result = <String, double>{};
    for (final key in const ['x', 'y', 'z', 'r']) {
      final raw = pose[key] ?? pose[key.toUpperCase()];
      final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (value == null) return null;
      result[key] = value;
    }
    return result;
  }

  Future<Map<String, double>?> _refreshPose() async {
    final machine = await widget.controller.machinesApi.find(widget.machine.id);
    widget.controller.replaceSelectedMachine(machine);
    return _poseOf(machine);
  }

  String _fmt(Map<String, double>? pose) {
    if (pose == null) return 'Não ensinado';
    return 'X ${pose['x']!.toStringAsFixed(1)}  Y ${pose['y']!.toStringAsFixed(1)}\nZ ${pose['z']!.toStringAsFixed(1)}  R ${pose['r']!.toStringAsFixed(1)}';
  }

  Future<void> _capture(String point) async {
    if (_running) return;
    try {
      final pose = _poseOf(_latestMachine) ?? await _refreshPose();
      if (pose == null) throw const ApiException('A posição atual do Dobot ainda não está disponível.');
      if (!mounted) return;
      setState(() {
        _points[point] = Map<String, double>.from(pose);
        _status = '$point • ${_labels[point]} ensinado';
      });
    } on ApiException catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
    }
  }

  bool _reached(Map<String, double>? actual, Map<String, double> target) {
    if (actual == null) return false;
    return (actual['x']! - target['x']!).abs() <= 3 &&
        (actual['y']! - target['y']!).abs() <= 3 &&
        (actual['z']! - target['z']!).abs() <= 3 &&
        (actual['r']! - target['r']!).abs() <= 4;
  }

  Future<void> _waitPaused() async {
    while (_running && _paused && !_stopRequested) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (_stopRequested) throw const _DobotCycleStopped();
  }

  Future<void> _move(String point) async {
    await _waitPaused();
    final target = _points[point];
    if (target == null) throw ApiException('$point ainda não foi ensinado.');
    final queued = await widget.controller.machinesApi.sendDobotCommand(widget.machine.id, 'DOBOT_PTP', {
      ...target,
      'velocidade': _speed.round(),
    });
    final command = queued['comando'];
    final commandId = command is Map ? int.tryParse('${command['id']}') : null;
    if (commandId == null) throw const ApiException('O backend não retornou o identificador do comando.');
    final deadline = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(deadline)) {
      if (_stopRequested) throw const _DobotCycleStopped();
      final statusData = await widget.controller.machinesApi.dobotCommandStatus(widget.machine.id, commandId);
      final status = '${statusData['status'] ?? ''}'.toUpperCase();
      if (status == 'CONCLUIDO') {
        final actual = await _refreshPose();
        if (_reached(actual, target)) return;
        throw ApiException('$point foi processado pelo Edge, mas a posição recebida não confirmou o alvo.');
      }
      if (status == 'FALHOU' || status == 'CANCELADO' || status == 'EXPIRADO') {
        throw ApiException('O Edge informou ${status.toLowerCase()} para o movimento. Consulte Diagnóstico / logs.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
    throw const ApiException('O Edge não confirmou a execução do movimento dentro do tempo esperado.');
  }

  Future<void> _command(String command) async {
    await _waitPaused();
    final queued = await widget.controller.machinesApi.sendDobotCommand(widget.machine.id, command);
    final item = queued['comando'];
    final commandId = item is Map ? int.tryParse('${item['id']}') : null;
    if (commandId == null) throw const ApiException('O backend não retornou o identificador do comando.');
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      if (_stopRequested) throw const _DobotCycleStopped();
      final statusData = await widget.controller.machinesApi.dobotCommandStatus(widget.machine.id, commandId);
      final status = '${statusData['status'] ?? ''}'.toUpperCase();
      if (status == 'CONCLUIDO') return;
      if (status == 'FALHOU' || status == 'CANCELADO' || status == 'EXPIRADO') throw ApiException('O Edge informou ${status.toLowerCase()} para $command.');
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
    throw ApiException('O Edge não confirmou $command dentro do tempo esperado.');
  }

  Future<void> _setStep(String label, double progress) async {
    if (!mounted) return;
    setState(() {
      _step = label;
      _progress = progress.clamp(0.0, 1.0).toDouble();
    });
  }

  Future<void> _start() async {
    if (_running) return;
    final missing = _labels.keys.where((point) => !_points.containsKey(point)).toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ensine todos os pontos antes de iniciar. Faltam: ${missing.join(', ')}.')));
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Iniciar ciclo automático?'),
        content: Text('Serão executados $_cycles ciclo(s) de pick-and-place a ${_speed.round()}%. Confirme que P0–P4 estão livres de colisão e que a área do Dobot está desimpedida.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('INICIAR')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    setState(() {
      _running = true;
      _paused = false;
      _stopRequested = false;
      _completed = 0;
      _progress = 0;
      _status = 'Ciclo em execução';
      _step = 'Preparando sequência';
    });
    widget.onRunningChanged(true);

    final sequence = <MapEntry<String, Future<void> Function()>>[
      MapEntry('Ir para espera', () => _move('P0')),
      MapEntry('Aproximar da peça', () => _move('P1')),
      MapEntry('Descer para coleta', () => _move('P2')),
      MapEntry('Fixar peça • Ventosa ON', () => _command('DOBOT_SUCTION_ON')),
      MapEntry('Elevar peça', () => _move('P1')),
      MapEntry('Transportar ao destino', () => _move('P3')),
      MapEntry('Descer para entrega', () => _move('P4')),
      MapEntry('Liberar peça • Ventosa OFF', () => _command('DOBOT_SUCTION_OFF')),
      MapEntry('Recuar do destino', () => _move('P3')),
      MapEntry('Retornar à espera', () => _move('P0')),
    ];

    try {
      for (var cycle = 0; cycle < _cycles; cycle++) {
        for (var index = 0; index < sequence.length; index++) {
          if (_stopRequested) throw const _DobotCycleStopped();
          await _waitPaused();
          final item = sequence[index];
          final current = cycle * sequence.length + index;
          await _setStep(item.key, current / (_cycles * sequence.length));
          if (mounted) setState(() => _status = 'Ciclo ${cycle + 1} de $_cycles');
          await item.value();
        }
        if (mounted) {
          setState(() {
            _completed = cycle + 1;
            _progress = _completed / _cycles;
            _status = 'Ciclo $_completed concluído';
          });
        }
      }
      if (mounted) {
        setState(() {
          _status = 'Sequência concluída';
          _step = 'Pronto para novo ciclo';
          _progress = 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_completed ciclo(s) automático(s) concluído(s).')));
      }
    } on _DobotCycleStopped {
      if (mounted) setState(() { _status = 'Parado pelo operador'; _step = 'Movimento interrompido'; });
    } on ApiException catch (exception) {
      try { await widget.controller.machinesApi.sendDobotCommand(widget.machine.id, 'DOBOT_STOP'); } catch (_) {}
      if (mounted) {
        setState(() { _status = 'Ciclo interrompido'; _step = exception.message; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } finally {
      if (mounted) {
        setState(() { _running = false; _paused = false; _stopRequested = false; });
      }
      widget.onRunningChanged(false);
    }
  }

  Future<void> _stop() async {
    if (!_running) return;
    setState(() { _stopRequested = true; _paused = false; _status = 'Parando'; _step = 'Enviando DOBOT_STOP'; });
    try {
      await widget.controller.machinesApi.sendDobotCommand(widget.machine.id, 'DOBOT_STOP');
    } on ApiException catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
    }
  }

  void _pause() {
    if (!_running) return;
    setState(() {
      _paused = !_paused;
      _status = _paused ? 'Pausado após a etapa atual' : 'Ciclo retomado';
      _step = _paused ? 'Aguardando operador' : 'Retomando sequência';
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SectionCard(
      accent: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _DobotIconBox(icon: Icons.precision_manufacturing_outlined),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ciclo automático industrial', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    SizedBox(height: 2),
                    Text('Ensine 5 pontos reais e execute um pick-and-place repetível.', style: TextStyle(color: SteelColors.muted, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: SteelColors.industrialAccent.withValues(alpha: .10), borderRadius: BorderRadius.circular(9)),
                child: Text(_status, style: const TextStyle(color: SteelColors.industrialAccent, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850 ? 5 : constraints.maxWidth >= 560 ? 2 : 1;
              final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - (columns - 1) * 9) / columns;
              return Wrap(
                spacing: 9,
                runSpacing: 9,
                children: _labels.entries.map((entry) {
                  final taught = _points[entry.key];
                  return SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: taught != null ? SteelColors.success.withValues(alpha: dark ? .08 : .05) : dark ? const Color(0xFF20282D) : const Color(0xFFF7F8F8),
                        border: Border.all(color: taught != null ? SteelColors.success.withValues(alpha: .35) : dark ? SteelColors.borderDark : SteelColors.border),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [Text(entry.key, style: const TextStyle(color: SteelColors.industrialAccent, fontWeight: FontWeight.w900)), const SizedBox(width: 7), Expanded(child: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10)))]),
                          const SizedBox(height: 7),
                          Text(_fmt(taught), style: TextStyle(color: taught != null ? SteelColors.success : SteelColors.muted, fontSize: 9, height: 1.4)),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _running ? null : () => _capture(entry.key),
                            icon: const Icon(Icons.my_location_rounded, size: 14),
                            label: const Text('Capturar atual', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 580;
              final cycles = DropdownButtonFormField<int>(
                value: _cycles,
                decoration: const InputDecoration(labelText: 'Repetições', isDense: true),
                items: const [1, 2, 3, 5, 10].map((value) => DropdownMenuItem(value: value, child: Text('$value'))).toList(),
                onChanged: _running ? null : (value) => setState(() => _cycles = value ?? 1),
              );
              final speed = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Velocidade automática • ${_speed.round()}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                  Slider(value: _speed, min: 1, max: 40, divisions: 39, onChanged: _running ? null : (value) => setState(() => _speed = value)),
                ],
              );
              if (compact) return Column(children: [cycles, const SizedBox(height: 10), speed]);
              return Row(children: [SizedBox(width: 150, child: cycles), const SizedBox(width: 14), Expanded(child: speed)]);
            },
          ),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: Text(_step, style: const TextStyle(color: SteelColors.muted, fontSize: 10))), Text('$_completed / $_cycles', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10))]),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: _progress, minHeight: 7, borderRadius: BorderRadius.circular(10), color: SteelColors.industrialAccent),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 520;
              final start = FilledButton.icon(
                onPressed: _running ? null : _start,
                style: FilledButton.styleFrom(backgroundColor: SteelColors.industrialAccent, foregroundColor: Colors.white, minimumSize: const Size(160, 46)),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('INICIAR CICLO'),
              );
              final pause = OutlinedButton.icon(onPressed: _running ? _pause : null, icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded), label: Text(_paused ? 'CONTINUAR' : 'PAUSAR'));
              final stop = FilledButton.icon(onPressed: _running ? _stop : null, style: FilledButton.styleFrom(backgroundColor: SteelColors.danger, foregroundColor: Colors.white), icon: const Icon(Icons.stop_rounded), label: const Text('PARAR'));
              if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [start, const SizedBox(height: 8), pause, const SizedBox(height: 8), stop]);
              return Row(children: [Expanded(child: start), const SizedBox(width: 8), Expanded(child: pause), const SizedBox(width: 8), Expanded(child: stop)]);
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: SteelColors.warning.withValues(alpha: .08), border: Border.all(color: SteelColors.warning.withValues(alpha: .22)), borderRadius: BorderRadius.circular(10)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.warning_amber_rounded, color: SteelColors.warning, size: 18), SizedBox(width: 8), Expanded(child: Text('O automático bloqueia o modo manual durante o ciclo. PAUSAR atua entre etapas; PARAR envia DOBOT_STOP imediatamente. Ensine P0–P4 sem colisões e mantenha a área do braço livre.', style: TextStyle(color: SteelColors.muted, fontSize: 10, height: 1.4)))]),
          ),
        ],
      ),
    );
  }
}

class _DobotCycleStopped implements Exception {
  const _DobotCycleStopped();
}

class _DobotIconBox extends StatelessWidget {
  const _DobotIconBox({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF222B30) : SteelColors.panelLight,
        border: Border.all(color: dark ? SteelColors.borderDark : SteelColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: SteelColors.industrialAccent, size: 20),
    );
  }
}

class _DobotValuesCard extends StatelessWidget {
  const _DobotValuesCard({
    required this.icon,
    required this.title,
    required this.labels,
    required this.values,
    required this.unit,
  });

  final IconData icon;
  final String title;
  final List<String> labels;
  final List<String> values;
  final List<String> unit;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SectionCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _DobotIconBox(icon: icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: List.generate(labels.length, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 7),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF20282D) : const Color(0xFFF5F7F7),
                    border: Border.all(
                      color: dark ? SteelColors.borderDark : SteelColors.border,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[index],
                        style: const TextStyle(
                          color: SteelColors.industrialAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        values[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unit[index],
                        style: const TextStyle(color: SteelColors.muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
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

  double? _value(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.'));

  Future<void> _send() async {
    final values = [_value(_x), _value(_y), _value(_z), _value(_r)];
    if (values.any((value) => value == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).get('ptpFieldsRequired'))),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.controller.machinesApi.sendDobotCommand(
        widget.machine.id,
        'DOBOT_PTP',
        {
          'x': values[0],
          'y': values[1],
          'z': values[2],
          'r': values[3],
          'velocidade': _speed.round(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).get('ptpSent'))),
        );
      }
    } on ApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exception.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SectionCard(
      accent: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DobotIconBox(icon: Icons.control_camera_rounded),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.get('ptpMovement'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.get('safetyValidationCaption'),
                      style: const TextStyle(color: SteelColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: SteelColors.industrialAccent.withValues(alpha: .08),
                  border: Border.all(
                    color: SteelColors.industrialAccent.withValues(alpha: .28),
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: SteelColors.industrialAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      strings.get('protectedMovement'),
                      style: const TextStyle(
                        color: SteelColors.industrialAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 4 : 2;
              final fieldWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AxisField(width: fieldWidth, controller: _x, label: 'X', unit: 'mm'),
                  _AxisField(width: fieldWidth, controller: _y, label: 'Y', unit: 'mm'),
                  _AxisField(width: fieldWidth, controller: _z, label: 'Z', unit: 'mm'),
                  _AxisField(width: fieldWidth, controller: _r, label: 'R', unit: '°'),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final slider = Row(
                children: [
                  const Icon(Icons.speed_rounded, size: 18, color: SteelColors.industrialAccent),
                  const SizedBox(width: 8),
                  Text(
                    strings.get('speed'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: _speed,
                      min: 1,
                      max: 100,
                      divisions: 99,
                      label: '${_speed.round()}%',
                      onChanged: (value) => setState(() => _speed = value),
                    ),
                  ),
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF20282D) : SteelColors.panelLight,
                      border: Border.all(
                        color: dark ? SteelColors.borderDark : SteelColors.border,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_speed.round()}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ],
              );
              final send = FilledButton.icon(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(150, 46),
                  backgroundColor: SteelColors.industrialAccent,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(_sending ? Icons.hourglass_top_rounded : Icons.send_rounded),
                label: Text(_sending ? strings.get('sending') : strings.get('sendPtp')),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [slider, const SizedBox(height: 12), send],
                );
              }
              return Row(
                children: [Expanded(child: slider), const SizedBox(width: 12), send],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AxisField extends StatelessWidget {
  const _AxisField({
    required this.width,
    required this.controller,
    required this.label,
    required this.unit,
  });

  final double width;
  final TextEditingController controller;
  final String label;
  final String unit;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(
            labelText: label,
            suffixText: unit,
            isDense: true,
          ),
        ),
      );
}

class _DobotCommandTile extends StatelessWidget {
  const _DobotCommandTile({
    required this.width,
    required this.label,
    required this.command,
    required this.icon,
    required this.controller,
    required this.machine,
    this.danger = false,
  });

  final double width;
  final String label;
  final String command;
  final IconData icon;
  final AppController controller;
  final Machine machine;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = danger ? SteelColors.danger : Theme.of(context).colorScheme.onSurface;
    final background = danger
        ? SteelColors.danger.withValues(alpha: dark ? .13 : .07)
        : (dark ? const Color(0xFF20282D) : const Color(0xFFF6F7F7));
    final border = danger
        ? SteelColors.danger.withValues(alpha: .28)
        : (dark ? SteelColors.borderDark : SteelColors.border);

    return SizedBox(
      width: width,
      height: 49,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () async {
          try {
            await controller.machinesApi.sendDobotCommand(machine.id, command);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppStrings.of(context)
                        .get('commandSent')
                        .replaceAll('{command}', label),
                  ),
                ),
              );
            }
          } on ApiException catch (exception) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(exception.message)),
              );
            }
          }
        },
        icon: Icon(icon, size: 18, color: danger ? SteelColors.danger : SteelColors.industrialAccent),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
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
    if (mounted) setState(() => _telemetry = next);
    await Future.wait([next, widget.controller.refreshSelectedMachine()]);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final profile = _operationalProfile(widget.machine, strings);
    final controllerName = (widget.machine.controller ?? '').toUpperCase();
    final robotic = controllerName.contains('DOBOT') || controllerName.contains('ROBOT');
    final operationTitle = robotic ? strings.get('robotArmOperation') : strings.get('equipmentOperation');

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _telemetry,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        final points = _productionPoints(items, widget.machine);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              _ProductionHeader(machine: widget.machine, profile: profile),
              const SizedBox(height: 18),
              Text(
                operationTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                strings.get('productionSimpleCaption'),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? SteelColors.mutedDark : SteelColors.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final chart = _ProductionChartCard(
                    profile: profile,
                    points: points,
                    loading: snapshot.connectionState == ConnectionState.waiting,
                  );
                  final summary = _ProductiveSummary(
                    machine: widget.machine,
                    profile: profile,
                  );

                  if (!wide) {
                    return Column(
                      children: [
                        chart,
                        const SizedBox(height: 14),
                        summary,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: chart),
                      const SizedBox(width: 14),
                      Expanded(child: summary),
                    ],
                  );
                },
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 12),
                _ProductionNotice(
                  icon: Icons.cloud_off_outlined,
                  title: strings.get('noTelemetry'),
                  message: '${snapshot.error}',
                  color: SteelColors.warning,
                ),
              ] else if (items.isEmpty && !widget.machine.simulation) ...[
                const SizedBox(height: 12),
                _ProductionNotice(
                  icon: Icons.sensors_off_outlined,
                  title: strings.get('noTelemetry'),
                  message: strings.get('realStaysOffline'),
                  color: SteelColors.warning,
                ),
              ],
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF2A343A) : const Color(0xFF53616C),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(profile.icon, color: Colors.white, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name.toUpperCase(),
                    style: const TextStyle(
                      color: SteelColors.industrialAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    machine.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    strings.get('productionLinkedToEquipment'),
                    style: TextStyle(color: dark ? SteelColors.mutedDark : SteelColors.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SteelColors.industrialAccent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                machine.simulation ? strings.get('simulation') : strings.get('real'),
                style: const TextStyle(
                  color: SteelColors.industrialAccent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.of(context).get('productionChart'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            profile.chartLabel,
            style: TextStyle(color: dark ? SteelColors.mutedDark : SteelColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            width: double.infinity,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _ProductionBars(points: points),
          ),
        ],
      ),
    );
  }
}

class _ProductiveSummary extends StatelessWidget {
  const _ProductiveSummary({required this.machine, required this.profile});
  final Machine machine;
  final _OperationalProfile profile;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(strings.get('productiveSummary'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _SummaryLine(label: profile.primaryLabel, value: '${machine.production}'),
          _SummaryLine(label: strings.get('cyclesReported'), value: '${machine.cycles}'),
          _SummaryLine(label: strings.get('status'), value: strings.translate(machine.status), color: _statusColor(machine)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF20292E) : SteelColors.panelLight,
              border: Border.all(color: dark ? SteelColors.borderDark : SteelColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.metricLabel,
                  style: const TextStyle(color: SteelColors.industrialAccent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .45),
                ),
                const SizedBox(height: 5),
                Text(profile.metricValue, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: profile.resources
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: SteelColors.industrialAccent.withValues(alpha: .07),
                            border: Border.all(color: SteelColors.industrialAccent.withValues(alpha: .16)),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(item, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductionNotice extends StatelessWidget {
  const _ProductionNotice({required this.icon, required this.title, required this.message, required this.color});
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(color: SteelColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: SteelColors.muted, fontSize: 12))),
            const SizedBox(width: 10),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
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
              final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('maintenanceCenter'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('${strings.get('maintenanceHistory')} • ${widget.machine.name}', style: const TextStyle(color: SteelColors.muted))]);
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
            SectionCard(child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.handyman_outlined, color: SteelColors.primary)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('maintenanceCenter'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 3), Text(strings.get('maintenancePermission'), style: const TextStyle(color: SteelColors.muted, fontSize: 12))])), if (_busy) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))])),
            const SizedBox(height: 14),
            Text(strings.get('maintenanceHistory'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(strings.translate(item.type), style: const TextStyle(fontWeight: FontWeight.w700))), _MaintenanceId(id: item.id)]), const SizedBox(height: 5), Text(item.description), const SizedBox(height: 9), Wrap(spacing: 14, runSpacing: 5, children: [Text('${strings.get('responsibleTechnician')}: ${item.technician}', style: const TextStyle(color: SteelColors.muted, fontSize: 12)), Text('${item.date} • ${item.time}', style: const TextStyle(color: SteelColors.muted, fontSize: 12)), if (item.cycles != null) Text('${strings.get('cycles')}: ${item.cycles}', style: const TextStyle(color: SteelColors.muted, fontSize: 12))])])),
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

class _MaintenanceId extends StatelessWidget { const _MaintenanceId({required this.id}); final int id; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(99)), child: Text('#$id', style: const TextStyle(color: SteelColors.primary, fontSize: 10, fontWeight: FontWeight.w700))); }

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
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
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

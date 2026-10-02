import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/machine.dart';
import 'section_card.dart';

class DynamicIndustrialDashboard extends StatelessWidget {
  const DynamicIndustrialDashboard({required this.machine, super.key});

  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final resolver = _IndustrialValueResolver(machine);
    final sections = <_IndustrialSection>[
      _performanceSection(resolver),
      _productionSection(resolver),
      _safetySection(resolver),
      _maintenanceSection(resolver),
      _energySection(resolver),
      ..._customSections(machine, resolver),
    ].map((section) => section.onlyAvailable()).where((section) => section.metrics.isNotEmpty).toList();
    final configured = sections.expand((section) => section.metrics).length;

    if (sections.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      accent: true,
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: PageStorageKey<String>('industrial-dashboard-${machine.id}'),
        initiallyExpanded: false,
        maintainState: true,
        tilePadding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: SteelColors.industrialAccent.withValues(alpha: .10),
            border: Border.all(color: SteelColors.industrialAccent.withValues(alpha: .28)),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.dashboard_customize_outlined, color: SteelColors.industrialAccent),
        ),
        title: Text(
          'Indicadores avançados',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '$configured sinais reais recebidos do Edge ou controlador',
          style: const TextStyle(color: SteelColors.muted, fontSize: 10),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: SteelColors.industrialAccent.withValues(alpha: .06),
                border: Border.all(color: SteelColors.industrialAccent.withValues(alpha: .22)),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: SteelColors.industrialAccent, size: 17),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Painel somente de leitura: organiza dados extras enviados pela máquina. Não movimenta nem configura o equipamento.',
                      style: TextStyle(color: SteelColors.muted, fontSize: 10, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...sections.map(
            (section) => _IndustrialSectionTile(section: section, initiallyExpanded: false),
          ),
        ],
      ),
    );
  }
}

class _IndustrialSectionTile extends StatelessWidget {
  const _IndustrialSectionTile({required this.section, required this.initiallyExpanded});

  final _IndustrialSection section;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: PageStorageKey<String>('industrial-section-${section.title}'),
      initiallyExpanded: initiallyExpanded,
      maintainState: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: section.color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(section.icon, color: section.color, size: 19),
      ),
      title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      subtitle: Text(section.caption, style: const TextStyle(color: SteelColors.muted, fontSize: 9.5)),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 540
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 104,
              children: section.metrics.map((metric) => _IndustrialMetricCard(metric: metric)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _IndustrialMetricCard extends StatelessWidget {
  const _IndustrialMetricCard({required this.metric});

  final _IndustrialMetric metric;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = metric.available ? metric.color : SteelColors.muted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF20282D) : const Color(0xFFF8F9F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: metric.available
              ? color.withValues(alpha: .24)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(metric.icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SteelColors.muted, fontSize: 9.5)),
                const SizedBox(height: 4),
                Text(metric.displayValue, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: metric.available ? null : SteelColors.muted, fontWeight: FontWeight.w800, fontSize: 14, height: 1.05)),
                if (metric.caption != null) ...[
                  const SizedBox(height: 3),
                  Text(metric.caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SteelColors.muted, fontSize: 8.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IndustrialSection {
  const _IndustrialSection({required this.title, required this.caption, required this.icon, required this.color, required this.metrics});
  final String title;
  final String caption;
  final IconData icon;
  final Color color;
  final List<_IndustrialMetric> metrics;

  _IndustrialSection onlyAvailable() => _IndustrialSection(
        title: title,
        caption: caption,
        icon: icon,
        color: color,
        metrics: metrics.where((metric) => metric.available).toList(),
      );
}

class _IndustrialMetric {
  const _IndustrialMetric({required this.label, required this.value, required this.icon, required this.color, this.unit = '', this.caption, this.trueLabel = 'ATIVO', this.falseLabel = 'NORMAL'});
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
  final String unit;
  final String? caption;
  final String trueLabel;
  final String falseLabel;

  bool get available => value != null && '$value'.trim().isNotEmpty;

  String get displayValue {
    if (!available) return 'Não informado';
    if (value is bool) return value == true ? trueLabel : falseLabel;
    if (value is num) {
      final number = value as num;
      final digits = number.toDouble() % 1 == 0 ? 0 : 1;
      return '${number.toStringAsFixed(digits)}${unit.isEmpty ? '' : ' $unit'}';
    }
    return '${value.toString()}${unit.isEmpty ? '' : ' $unit'}';
  }
}

class _IndustrialValueResolver {
  _IndustrialValueResolver(this.machine);

  final Machine machine;

  dynamic first(List<String> paths, {dynamic fallback}) {
    for (final path in paths) {
      final fromTelemetry = _path(machine.extraData, path);
      if (_present(fromTelemetry)) return fromTelemetry;
    }
    return fallback;
  }

  dynamic _path(Map<String, dynamic> source, String path) {
    dynamic current = source;
    for (final segment in path.split('.')) {
      if (current is! Map || !current.containsKey(segment)) return null;
      current = current[segment];
    }
    return current;
  }

  bool _present(dynamic value) => value != null && '$value'.trim().isNotEmpty;

  double? number(List<String> paths) {
    final value = first(paths);
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  double? percent(List<String> paths) {
    final value = number(paths);
    if (value == null) return null;
    return value >= 0 && value <= 1 ? value * 100 : value;
  }

  double? get oee {
    final direct = percent(['kpi.oee', 'oee.value', 'oee']);
    if (direct != null) return direct;
    final availability = percent(['kpi.availability', 'oee.availability', 'availability']);
    final performance = percent(['kpi.performance', 'oee.performance', 'performance']);
    final quality = percent(['kpi.quality', 'oee.quality', 'quality']);
    if (availability == null || performance == null || quality == null) return null;
    return (availability * performance * quality) / 10000;
  }
}

_IndustrialSection _performanceSection(_IndustrialValueResolver r) => _IndustrialSection(
      title: 'Eficiência e OEE',
      caption: 'Disponibilidade, desempenho, qualidade e tempo de ciclo.',
      icon: Icons.speed_rounded,
      color: SteelColors.industrialAccent,
      metrics: [
        _IndustrialMetric(label: 'OEE', value: r.oee, unit: '%', icon: Icons.donut_large_rounded, color: SteelColors.industrialAccent, caption: 'Eficiência global'),
        _IndustrialMetric(label: 'Disponibilidade', value: r.percent(['kpi.availability', 'oee.availability', 'availability']), unit: '%', icon: Icons.av_timer_rounded, color: SteelColors.success),
        _IndustrialMetric(label: 'Desempenho', value: r.percent(['kpi.performance', 'oee.performance', 'performance']), unit: '%', icon: Icons.trending_up_rounded, color: SteelColors.primary),
        _IndustrialMetric(label: 'Qualidade', value: r.percent(['kpi.quality', 'oee.quality', 'quality']), unit: '%', icon: Icons.verified_outlined, color: SteelColors.success),
        _IndustrialMetric(label: 'Ciclo real', value: r.number(['kpi.cycleTimeSec', 'cycleTimeSec', 'cycle.timeSec', 'hmi.cycleTimeSec']), unit: 's', icon: Icons.timer_outlined, color: SteelColors.primary),
        _IndustrialMetric(label: 'Ciclo planejado', value: r.number(['kpi.targetCycleTimeSec', 'targetCycleTimeSec', 'cycle.targetSec']), unit: 's', icon: Icons.flag_outlined, color: SteelColors.warning),
      ],
    );

_IndustrialSection _productionSection(_IndustrialValueResolver r) => _IndustrialSection(
      title: 'Produção e qualidade',
      caption: 'Ordem, lote, receita, peças boas e refugos.',
      icon: Icons.precision_manufacturing_outlined,
      color: SteelColors.success,
      metrics: [
        _IndustrialMetric(label: 'Peças boas', value: r.first(['quality.goodCount', 'production.good', 'goodParts']), unit: 'un.', icon: Icons.check_circle_outline_rounded, color: SteelColors.success),
        _IndustrialMetric(label: 'Refugos', value: r.first(['quality.rejectCount', 'production.rejects', 'rejects', 'scrapCount']), unit: 'un.', icon: Icons.remove_circle_outline_rounded, color: SteelColors.danger),
        _IndustrialMetric(label: 'Ordem de produção', value: r.first(['production.workOrder', 'workOrder', 'order.id']), icon: Icons.assignment_outlined, color: SteelColors.primary),
        _IndustrialMetric(label: 'Lote', value: r.first(['production.batch', 'batch', 'lot']), icon: Icons.qr_code_2_rounded, color: SteelColors.primary),
        _IndustrialMetric(label: 'Receita / programa', value: r.first(['production.recipe', 'recipe', 'program', 'cnc.program']), icon: Icons.description_outlined, color: SteelColors.primary),
      ],
    );

_IndustrialSection _safetySection(_IndustrialValueResolver r) => _IndustrialSection(
      title: 'Segurança e intertravamentos',
      caption: 'Condições informadas pela máquina; não substituem dispositivos físicos certificados.',
      icon: Icons.health_and_safety_outlined,
      color: SteelColors.danger,
      metrics: [
        _IndustrialMetric(label: 'Circuito E-stop', value: r.first(['safety.estopOk', 'hmi.interlocks.estopOk']), icon: Icons.stop_circle_outlined, color: SteelColors.danger, trueLabel: 'OK', falseLabel: 'BLOQUEADO'),
        _IndustrialMetric(label: 'Portas / proteções', value: r.first(['safety.doorClosed', 'hmi.interlocks.doorClosed']), icon: Icons.door_front_door_outlined, color: SteelColors.warning, trueLabel: 'FECHADAS', falseLabel: 'ABERTAS'),
        _IndustrialMetric(label: 'Permissão de START', value: r.first(['safety.startPermit', 'hmi.interlocks.startAllowed']), icon: Icons.play_circle_outline_rounded, color: SteelColors.success, trueLabel: 'LIBERADA', falseLabel: 'BLOQUEADA'),
        _IndustrialMetric(label: 'Modo operacional', value: r.first(['operation.mode', 'mode', 'hmi.mode', 'robot.mode', 'dobot.mode']), icon: Icons.tune_rounded, color: SteelColors.primary),
        _IndustrialMetric(label: 'Alarmes do processo', value: r.first(['alarms.activeCount', 'alarmCount', 'alarmsActive']), icon: Icons.warning_amber_rounded, color: SteelColors.warning),
      ],
    );

_IndustrialSection _maintenanceSection(_IndustrialValueResolver r) => _IndustrialSection(
      title: 'Manutenção e confiabilidade',
      caption: 'Horas, MTBF, MTTR, vida útil e planejamento preventivo.',
      icon: Icons.build_circle_outlined,
      color: SteelColors.warning,
      metrics: [
        _IndustrialMetric(label: 'Horas de operação', value: r.number(['maintenance.runtimeHours', 'runtimeHours', 'operatingHours']), unit: 'h', icon: Icons.schedule_rounded, color: SteelColors.primary),
        _IndustrialMetric(label: 'MTBF', value: r.number(['maintenance.mtbfHours', 'mtbfHours', 'mtbf']), unit: 'h', icon: Icons.timeline_rounded, color: SteelColors.success),
        _IndustrialMetric(label: 'MTTR', value: r.number(['maintenance.mttrMinutes', 'mttrMinutes', 'mttr']), unit: 'min', icon: Icons.handyman_outlined, color: SteelColors.warning),
        _IndustrialMetric(label: 'Vida da ferramenta', value: r.number(['maintenance.toolLifePercent', 'tool.lifePercent', 'toolLife']), unit: '%', icon: Icons.construction_outlined, color: SteelColors.warning),
      ],
    );

_IndustrialSection _energySection(_IndustrialValueResolver r) => _IndustrialSection(
      title: 'Energia e conectividade',
      caption: 'Utilidades, consumo, latência, sinal e atualização dos dados.',
      icon: Icons.electric_bolt_outlined,
      color: SteelColors.primary,
      metrics: [
        _IndustrialMetric(label: 'Potência instantânea', value: r.number(['energy.powerKw', 'powerKw', 'utilities.powerKw']), unit: 'kW', icon: Icons.electric_meter_outlined, color: SteelColors.industrialAccent),
        _IndustrialMetric(label: 'Energia acumulada', value: r.number(['energy.totalKwh', 'totalKwh', 'utilities.energyKwh']), unit: 'kWh', icon: Icons.data_usage_rounded, color: SteelColors.primary),
        _IndustrialMetric(label: 'Ar comprimido', value: r.number(['utilities.airPressureBar', 'air.pressureBar', 'airPressure']), unit: 'bar', icon: Icons.air_rounded, color: SteelColors.primary),
      ],
    );

List<_IndustrialSection> _customSections(Machine machine, _IndustrialValueResolver resolver) {
  final dashboard = machine.integrationMeta['dashboard'];
  if (dashboard is! Map || dashboard['sections'] is! List) return const [];
  final sections = <_IndustrialSection>[];
  for (final rawSection in dashboard['sections'] as List) {
    if (rawSection is! Map || rawSection['metrics'] is! List) continue;
    final metrics = <_IndustrialMetric>[];
    for (final rawMetric in rawSection['metrics'] as List) {
      if (rawMetric is! Map) continue;
      final paths = rawMetric['paths'] is List
          ? (rawMetric['paths'] as List).map((item) => '$item').toList()
          : <String>['${rawMetric['path'] ?? ''}'];
      metrics.add(
        _IndustrialMetric(
          label: '${rawMetric['label'] ?? 'Indicador'}',
          value: resolver.first(paths.where((path) => path.isNotEmpty).toList()),
          unit: '${rawMetric['unit'] ?? ''}',
          icon: _icon('${rawMetric['icon'] ?? ''}'),
          color: SteelColors.industrialAccent,
          caption: rawMetric['caption']?.toString(),
        ),
      );
    }
    if (metrics.isEmpty) continue;
    sections.add(
      _IndustrialSection(
        title: '${rawSection['title'] ?? 'Indicadores personalizados'}',
        caption: '${rawSection['caption'] ?? 'Dados definidos para este equipamento.'}',
        icon: _icon('${rawSection['icon'] ?? ''}'),
        color: SteelColors.industrialAccent,
        metrics: metrics,
      ),
    );
  }
  return sections;
}

IconData _icon(String name) => switch (name.toLowerCase()) {
      'temperature' || 'thermostat' => Icons.thermostat_rounded,
      'vibration' => Icons.vibration_rounded,
      'energy' || 'bolt' => Icons.bolt_rounded,
      'production' || 'inventory' => Icons.inventory_2_outlined,
      'safety' || 'shield' => Icons.health_and_safety_outlined,
      'maintenance' || 'build' => Icons.build_circle_outlined,
      'network' || 'wifi' => Icons.wifi_rounded,
      'speed' || 'gauge' => Icons.speed_rounded,
      _ => Icons.monitor_heart_outlined,
    };

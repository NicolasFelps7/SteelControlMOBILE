import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/machine.dart';
import 'machine_model_3d.dart';

final machineProfiles = rootBundle
    .loadString('assets/machine-profiles.json')
    .then((s) => Map<String, dynamic>.from(jsonDecode(s) as Map));
dynamic profilePath(Map<String, dynamic> root, String path) {
  dynamic v = root;
  for (final key in path.split('.')) {
    if (v is! Map || !v.containsKey(key)) return null;
    v = v[key];
  }
  return v is num && !v.isFinite ? null : v;
}

Map<String, dynamic> profileMachineData(Machine m) => {
  'id': m.id,
  'tipo': m.type,
  'nome': m.name,
  'modelo': m.model,
  'controlador': m.controller,
  'dadosExtras': m.extraData,
  'estadoConexao': {'texto': m.connection},
  'latenciaMs': m.latencyMs,
  'ultimaTelemetriaEm': m.lastTelemetryAt?.toLocal().toString(),
  'paradaSeguranca': m.safetyStop,
};

class MachineProfilePanel extends StatelessWidget {
  const MachineProfilePanel({
    required this.machine,
    this.embedded = false,
    this.skipNear = false,
    super.key,
  });
  final Machine machine;
  final bool embedded;
  final bool skipNear;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: machineProfiles,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Center(child: Text('Não foi possível carregar o perfil.'));
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final data = profileMachineData(machine),
          profile = Map<String, dynamic>.from(
            snapshot.data![machine3dKind(data)] as Map,
          );
      return ListView(
        shrinkWrap: embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            profile['title'] as String,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            machine.hasRecentTelemetry
                ? 'Telemetria do equipamento'
                : 'Sem telemetria recente · últimos dados recebidos',
          ),
          const SizedBox(height: 12),
          for (final raw in (profile['sections'] as List).skip(
            skipNear ? (machine3dKind(data) == 'dobot' ? 2 : 1) : 0,
          ))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      raw['title'] as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final item in raw['metrics'] as List)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(item['label'] as String)),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                formatProfileValue(
                                  profilePath(data, item['path'] as String),
                                  item['unit'] as String,
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

String formatProfileValue(dynamic v, String unit) {
  if (v == null || (v is num && !v.isFinite)) return '— Sem dados';
  final text = v is bool
      ? (v ? 'Sim' : 'Não')
      : v is double
      ? v.toStringAsFixed(1)
      : '$v';
  return text.length > 100
      ? text.substring(0, 100)
      : '$text${unit.isEmpty ? '' : ' $unit'}';
}

class MachineNearTelemetry extends StatelessWidget {
  const MachineNearTelemetry({required this.machine, super.key});
  final Machine machine;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: machineProfiles,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final data = profileMachineData(machine),
          kind = machine3dKind(data),
          profile = Map<String, dynamic>.from(snapshot.data![kind] as Map),
          sections = (profile['sections'] as List).take(
            kind == 'dobot' ? 2 : 1,
          );
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(bottom: BorderSide(color: Color(0xffff922c))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final section in sections) ...[
              Text(
                '${section['title']}',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) {
                  final metrics = section['metrics'] as List;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in metrics)
                        Container(
                          width:
                              (c.maxWidth - 8 * (c.maxWidth > 450 ? 3 : 1)) /
                              (c.maxWidth > 450 ? 4 : 2),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(color: const Color(0xff43647a)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['label']}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatProfileValue(
                                  profilePath(data, '${item['path']}'),
                                  '${item['unit']}',
                                ),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
    },
  );
}

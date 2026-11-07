import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/machine.dart';
import 'machine_model_3d.dart';
import 'machine_profile_panel.dart';

/// Mantém o cenário 3D inteiro atrás dos painéis, como no dashboard original.
class MachinePlantBoard extends StatelessWidget {
  const MachinePlantBoard({
    required this.machine,
    required this.scene,
    required this.onMaintenance,
    super.key,
  });
  final Machine machine;
  final Widget scene;
  final VoidCallback onMaintenance;
  Widget panel(
    BuildContext context,
    String title,
    List<(String, String)> values, {
    Widget? action,
    bool inline = false,
  }) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withAlpha(246),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          color: const Color(0xffff922c),
          child: Text(
            title,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xff10202c),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: inline
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                item.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              : Column(
                  children: [
                    for (final item in values)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.$1,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                item.$2,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (action != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: action,
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: machineProfiles,
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const SizedBox(
          height: 760,
          child: Center(child: CircularProgressIndicator()),
        );
      final data = profileMachineData(machine),
          kind = machine3dKind(data),
          profile = Map<String, dynamic>.from(snapshot.data![kind] as Map),
          sections = profile['sections'] as List,
          remaining = sections.skip(kind == 'dobot' ? 2 : 1).toList();
      Widget section(dynamic section, {bool inline = false}) =>
          panel(context, '${section['title']}', [
            for (final item in section['metrics'] as List)
              (
                '${item['label']}',
                formatProfileValue(
                  profilePath(data, '${item['path']}'),
                  '${item['unit']}',
                ),
              ),
          ], inline: inline);
      final near = sections.take(kind == 'dobot' ? 2 : 1).toList();
      return LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth,
              height = math.max(840.0, width / 1.6),
              pw = width * .25;
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(child: scene),
                  Positioned(
                    top: 24,
                    left: 24,
                    width: pw,
                    child: Text(
                      'SUPERVISÃO INDUSTRIAL\n${machine.name}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: width * .28,
                    right: width * .28,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface
                            .withAlpha(248),
                        border: Border.all(color: const Color(0xffff922c)),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final raw in near) ...[
                            Text(
                              '${raw['title']}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final item in raw['metrics'] as List)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item['label']}',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: 8,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            formatProfileValue(
                                              profilePath(
                                                data,
                                                '${item['path']}',
                                              ),
                                              '${item['unit']}',
                                            ),
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 9),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 24,
                    right: 24,
                    width: pw,
                    child: section(remaining[0]),
                  ),
                  Positioned(
                    top: height * .34,
                    left: 24,
                    width: pw,
                    child: section(remaining[1]),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 24,
                    width: width * .62,
                    child: remaining.length > 2
                        ? section(remaining[2], inline: true)
                        : panel(context, 'Estado técnico do equipamento', [
                            ('Controlador', machine.controller ?? '—'),
                            ('Protocolo', machine.protocol ?? '—'),
                            ('Modelo', machine.model),
                            ('Estado', machine.connection),
                          ], inline: true),
                  ),
                  Positioned(
                    bottom: 40,
                    right: 24,
                    width: pw,
                    child: panel(
                      context,
                      'Manutenção do equipamento',
                      [
                        ('Situação', machine.maintenanceStatus),
                        ('Última intervenção', machine.lastMaintenance),
                        ('Próxima referência', machine.nextMaintenance),
                      ],
                      action: OutlinedButton(
                        onPressed: onMaintenance,
                        child: const Text('Abrir manutenção'),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 24,
                    right: 24,
                    child: Text(
                      machine.hasRecentTelemetry
                          ? 'Juntas medidas · telemetria recente'
                          : 'Sem telemetria recente · última posição recebida',
                      style: TextStyle(color: Color(0xffe9bf7a), fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

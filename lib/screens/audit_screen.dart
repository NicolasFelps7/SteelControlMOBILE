import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';
import '../widgets/section_card.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final _search = TextEditingController();

  List<Map<String, dynamic>> _entries = const [];
  bool _loading = true;
  String? _error;
  String _action = '';
  String _entity = '';
  String _actor = '';
  DateTime? _from;
  DateTime? _to;

  bool get _admin =>
      widget.controller.session?.user.role.toUpperCase() == 'ADMINISTRADOR';

  @override
  void initState() {
    super.initState();
    _search.addListener(_refreshFilters);
    _load();
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refreshFilters)
      ..dispose();
    super.dispose();
  }

  void _refreshFilters() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!_admin) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final entries = await widget.controller.companyApi.audit(limit: 300);
      entries.sort((a, b) {
        final left = _entryDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = _entryDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return _entries.where((entry) {
      final action = '${entry['acao'] ?? entry['action'] ?? ''}';
      final entity = '${entry['entidade'] ?? entry['entity'] ?? ''}';
      final actor = _actorName(entry);
      final date = _entryDate(entry);

      if (_action.isNotEmpty && action != _action) return false;
      if (_entity.isNotEmpty && entity != _entity) return false;
      if (_actor.isNotEmpty && actor != _actor) return false;

      if (_from != null && date != null) {
        final start = DateTime(_from!.year, _from!.month, _from!.day);
        if (date.isBefore(start)) return false;
      }
      if (_to != null && date != null) {
        final end = DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59, 999);
        if (date.isAfter(end)) return false;
      }

      if (query.isEmpty) return true;
      final searchable = [
        action,
        entity,
        actor,
        '${entry['entidadeId'] ?? entry['entityId'] ?? ''}',
        _detailsText(entry),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  List<String> _optionsFor(String key, {bool actor = false}) {
    final values = _entries
        .map((entry) => actor ? _actorName(entry) : '${entry[key] ?? ''}'.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _action = '';
      _entity = '';
      _actor = '';
      _from = null;
      _to = null;
    });
  }

  Future<void> _pickDate({required bool from}) async {
    final strings = AppStrings.of(context);
    final initial = from ? (_from ?? DateTime.now()) : (_to ?? DateTime.now());
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: from ? strings.get('auditFrom') : strings.get('auditTo'),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (from) {
        _from = value;
      } else {
        _to = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    if (!_admin) {
      return Center(
        child: SectionCard(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: SteelColors.primary,
                  size: 48,
                ),
                const SizedBox(height: 14),
                Text(
                  strings.get('auditAdminOnly'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filtered = _filtered;
    final today = DateTime.now();
    final todayCount = _entries.where((entry) {
      final date = _entryDate(entry);
      return date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).length;
    final actors = _entries.map(_actorName).where((name) => name.isNotEmpty).toSet().length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.get('audit'),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    strings.get('auditCaption'),
                    style: const TextStyle(color: SteelColors.muted),
                  ),
                ],
              );
              final refresh = FilledButton.tonalIcon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(strings.get('refresh')),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 12), refresh],
                );
              }
              return Row(children: [Expanded(child: title), refresh]);
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 540
                      ? 2
                      : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 118,
                children: [
                  MetricCard(
                    label: strings.get('auditLoaded'),
                    value: '${_entries.length}',
                    icon: Icons.inventory_2_outlined,
                    color: SteelColors.primary,
                  ),
                  MetricCard(
                    label: strings.get('auditFiltered'),
                    value: '${filtered.length}',
                    icon: Icons.filter_alt_outlined,
                    color: SteelColors.success,
                  ),
                  MetricCard(
                    label: strings.get('auditToday'),
                    value: '$todayCount',
                    icon: Icons.today_outlined,
                    color: SteelColors.warning,
                  ),
                  MetricCard(
                    label: strings.get('auditActors'),
                    value: '$actors',
                    icon: Icons.groups_2_outlined,
                    color: SteelColors.primary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _filters(strings),
          const SizedBox(height: 14),
          if (_loading)
            const SectionCard(
              child: Padding(
                padding: EdgeInsets.all(38),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_error != null)
            SectionCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: SteelColors.danger,
                    size: 42,
                  ),
                  const SizedBox(height: 10),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(strings.get('retry')),
                  ),
                ],
              ),
            )
          else if (filtered.isEmpty)
            SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(strings.get('auditNoResults'))),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings
                        .get('auditHistoryCount')
                        .replaceAll('{count}', '${filtered.length}'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  strings.get('auditNewestFirst'),
                  style: const TextStyle(color: SteelColors.muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...filtered.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AuditEntryCard(entry: entry),
              ),
            ),
          ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _filters(AppStrings strings) {
    final actions = _optionsFor('acao');
    final entities = _optionsFor('entidade');
    final actors = _optionsFor('', actor: true);

    Widget dropdown({
      required String label,
      required String value,
      required List<String> options,
      required ValueChanged<String> onChanged,
    }) {
      return DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: '', child: Text(strings.get('all'))),
          ...options.map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                label == strings.get('auditAction')
                    ? _auditActionLabel(strings, item)
                    : label == strings.get('auditEntity')
                        ? _auditEntityLabel(strings, item)
                        : item,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (next) => onChanged(next ?? ''),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: SteelColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  strings.get('auditFilters'),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(strings.get('clearFilters')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: strings.get('auditSearch'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _search.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                dropdown(
                  label: strings.get('auditAction'),
                  value: _action,
                  options: actions,
                  onChanged: (value) => setState(() => _action = value),
                ),
                dropdown(
                  label: strings.get('auditEntity'),
                  value: _entity,
                  options: entities,
                  onChanged: (value) => setState(() => _entity = value),
                ),
                dropdown(
                  label: strings.get('auditActor'),
                  value: _actor,
                  options: actors,
                  onChanged: (value) => setState(() => _actor = value),
                ),
              ];

              if (constraints.maxWidth < 720) {
                return Column(
                  children: fields
                      .expand((field) => [field, const SizedBox(height: 10)])
                      .toList()
                    ..removeLast(),
                );
              }
              return Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[1]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[2]),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(from: true),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _from == null
                      ? strings.get('auditFrom')
                      : '${strings.get('auditFrom')}: ${dateFormat.format(_from!)}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(from: false),
                icon: const Icon(Icons.event_available_outlined),
                label: Text(
                  _to == null
                      ? strings.get('auditTo')
                      : '${strings.get('auditTo')}: ${dateFormat.format(_to!)}',
                ),
              ),
              if (_from != null || _to != null)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _from = null;
                    _to = null;
                  }),
                  icon: const Icon(Icons.close_rounded),
                  label: Text(strings.get('clearDates')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  const _AuditEntryCard({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final action = '${entry['acao'] ?? entry['action'] ?? 'AÇÃO'}';
    final entity = '${entry['entidade'] ?? entry['entity'] ?? 'SISTEMA'}';
    final entityId = entry['entidadeId'] ?? entry['entityId'];
    final actor = _actorName(entry);
    final date = _entryDate(entry);
    final color = _actionColor(action);
    final details = _detailRows(entry);

    return SectionCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.fromLTRB(54, 0, 0, 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_actionIcon(action), color: color, size: 22),
          ),
          title: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _auditActionLabel(strings, action),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              _AuditBadge(label: _auditEntityLabel(strings, entity)),
              if (entityId != null) _AuditBadge(label: '#$entityId'),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text(
                  '${strings.get('auditActor')}: ${actor.isEmpty ? strings.get('system') : actor}',
                  style: const TextStyle(color: SteelColors.muted, fontSize: 11),
                ),
                if (date != null)
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm:ss').format(date),
                    style: const TextStyle(color: SteelColors.muted, fontSize: 11),
                  ),
              ],
            ),
          ),
          children: [
            if (details.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    strings.get('auditNoDetails'),
                    style: const TextStyle(color: SteelColors.muted),
                  ),
                ),
              )
            else
              ...details.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          _prettyKey(row.$1),
                          style: const TextStyle(
                            color: SteelColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          row.$2,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuditBadge extends StatelessWidget {
  const _AuditBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: SteelColors.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: SteelColors.primary.withValues(alpha: .13)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: SteelColors.primary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

DateTime? _entryDate(Map<String, dynamic> entry) {
  final raw = entry['criadoEm'] ??
      entry['createdAt'] ??
      entry['created_at'] ??
      entry['data'] ??
      entry['timestamp'];
  return DateTime.tryParse('$raw')?.toLocal();
}

String _actorName(Map<String, dynamic> entry) {
  final actor = entry['usuario'] ?? entry['user'] ?? entry['ator'];
  if (actor is Map) {
    return '${actor['nome'] ?? actor['name'] ?? actor['email'] ?? ''}'.trim();
  }
  final direct = entry['usuarioNome'] ??
      entry['userName'] ??
      entry['atorNome'] ??
      entry['emailUsuario'];
  return '${direct ?? ''}'.trim();
}

dynamic _detailsValue(Map<String, dynamic> entry) =>
    entry['detalhes'] ?? entry['details'] ?? entry['metadata'];

String _detailsText(Map<String, dynamic> entry) {
  final value = _detailsValue(entry);
  if (value == null) return '';
  if (value is String) return value;
  try {
    return jsonEncode(value);
  } catch (_) {
    return '$value';
  }
}

List<(String, String)> _detailRows(Map<String, dynamic> entry) {
  dynamic details = _detailsValue(entry);
  if (details is String) {
    try {
      details = jsonDecode(details);
    } catch (_) {
      return details.trim().isEmpty ? const [] : [('detalhes', details)];
    }
  }

  final rows = <(String, String)>[];

  void walk(dynamic value, String prefix, int depth) {
    if (rows.length >= 30 || depth > 3) return;
    if (value is Map) {
      for (final item in value.entries) {
        final next = prefix.isEmpty ? '${item.key}' : '$prefix.${item.key}';
        walk(item.value, next, depth + 1);
      }
      return;
    }
    if (value is List) {
      final text = value.map((item) => '$item').join(', ');
      rows.add((prefix, text));
      return;
    }
    if (value != null) rows.add((prefix, '$value'));
  }

  if (details != null) walk(details, '', 0);
  return rows;
}

String _prettyKey(String key) {
  if (key.isEmpty) return '-';
  final cleaned = key
      .replaceAll(RegExp(r'[_\.]+'), ' ')
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

String _auditActionLabel(AppStrings strings, String raw) {
  final normalized = raw.toUpperCase().trim();
  final key = switch (normalized) {
    'CRIAR' || 'CREATE' => 'auditCreate',
    'ATUALIZAR' || 'UPDATE' => 'auditUpdate',
    'DESATIVAR' || 'DISABLE' => 'auditDisable',
    'REMOVER' || 'DELETE' => 'auditRemove',
    'ATUALIZAR_LOGO' => 'auditUpdateLogo',
    'REMOVER_LOGO' => 'auditRemoveLogo',
    'LOGIN' => 'auditLogin',
    'LOGIN_FACIAL' || 'FACE_LOGIN' => 'auditFaceLogin',
    'CADASTRAR_FACE' || 'REGISTRAR_FACE' => 'auditFaceRegister',
    'REMOVER_FACE' => 'auditFaceRemove',
    'SIMULAR' || 'SIMULACAO' => 'auditSimulation',
    'COMANDO' || 'ENVIAR_COMANDO' => 'auditCommand',
    'LIBERAR_SEGURANCA' => 'auditSafetyRelease',
    _ => '',
  };
  return key.isEmpty ? _prettyKey(raw) : strings.get(key);
}

String _auditEntityLabel(AppStrings strings, String raw) {
  final normalized = raw.toUpperCase().trim();
  final key = switch (normalized) {
    'EMPRESA' => 'auditCompany',
    'USUARIO' || 'USUÁRIO' => 'auditUser',
    'MAQUINA' || 'MÁQUINA' => 'auditMachine',
    'MANUTENCAO' || 'MANUTENÇÃO' => 'auditMaintenance',
    'FACE' || 'FACIAL' => 'auditFace',
    'AUTENTICACAO' || 'AUTENTICAÇÃO' => 'auditAuthentication',
    'TELEMETRIA' => 'telemetry',
    'COMANDO' => 'auditCommandEntity',
    'SISTEMA' => 'system',
    _ => '',
  };
  return key.isEmpty ? _prettyKey(raw) : strings.get(key);
}

Color _actionColor(String raw) {
  final value = raw.toUpperCase();
  if (value.contains('REMOV') || value.contains('DESATIV')) {
    return SteelColors.danger;
  }
  if (value.contains('CRIAR') ||
      value.contains('CADAST') ||
      value.contains('LOGIN')) {
    return SteelColors.success;
  }
  if (value.contains('SEGUR') || value.contains('ALERTA')) {
    return SteelColors.warning;
  }
  return SteelColors.primary;
}

IconData _actionIcon(String raw) {
  final value = raw.toUpperCase();
  if (value.contains('LOGO')) return Icons.image_outlined;
  if (value.contains('LOGIN')) return Icons.login_rounded;
  if (value.contains('FACE')) return Icons.face_retouching_natural_rounded;
  if (value.contains('MAQUINA') || value.contains('MÁQUINA')) {
    return Icons.precision_manufacturing_outlined;
  }
  if (value.contains('REMOV') || value.contains('DESATIV')) {
    return Icons.remove_circle_outline_rounded;
  }
  if (value.contains('CRIAR') || value.contains('CADAST')) {
    return Icons.add_circle_outline_rounded;
  }
  if (value.contains('ATUAL')) return Icons.edit_outlined;
  return Icons.verified_user_outlined;
}

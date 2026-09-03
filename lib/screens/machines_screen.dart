import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';
import '../models/machine.dart';
import '../services/api_client.dart';
import '../state/app_controller.dart';
import '../widgets/section_card.dart';

class MachinesScreen extends StatefulWidget {
  const MachinesScreen({required this.controller, required this.onSelected, super.key});
  final AppController controller;
  final VoidCallback onSelected;
  @override State<MachinesScreen> createState() => _MachinesScreenState();
}

class _MachinesScreenState extends State<MachinesScreen> {
  bool _busy = false;
  final _searchController = TextEditingController();
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  bool get _admin => widget.controller.session?.user.role.toUpperCase() == 'ADMINISTRADOR';
  void _message(String value, {bool error = false}) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value), backgroundColor: error ? SteelColors.danger : SteelColors.success)); }
  Future<void> _run(Future<void> Function() action) async { if (_busy) return; setState(() => _busy = true); try { await action(); } on ApiException catch (e) { _message(e.message, error: true); } catch (e) { _message('$e', error: true); } finally { if (mounted) setState(() => _busy = false); } }

  Future<void> _create() async {
    final successMessage = AppStrings.of(context).get('machineCreated');
    final data = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _MachineDialog());
    if (data == null) return;
    await _run(() async { final result = await widget.controller.machinesApi.create(data); await widget.controller.loadMachines(); _message('${result['mensagem'] ?? successMessage}'); if (result['deviceKey'] != null && mounted) await _showKey('${result['deviceKey']}'); });
  }
  Future<void> _edit(Machine machine) async {
    final successMessage = AppStrings.of(context).get('machineUpdated');
    final full = await widget.controller.machinesApi.find(machine.id);
    if (!mounted) return;
    final data = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _MachineDialog(machine: full));
    if (data == null) return;
    await _run(() async { final result = await widget.controller.machinesApi.update(machine.id, data); await widget.controller.loadMachines(); _message('${result['mensagem'] ?? successMessage}'); if (result['deviceKey'] != null && mounted) await _showKey('${result['deviceKey']}'); });
  }
  Future<void> _remove(Machine machine) async {
    final strings = AppStrings.of(context);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(icon: const Icon(Icons.warning_amber_rounded, color: SteelColors.warning, size: 38), title: Text(strings.get('removeMachineTitle')), content: Text(strings.get('removeMachineMessage').replaceAll('{name}', machine.name)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.get('cancel'))), FilledButton(style: FilledButton.styleFrom(backgroundColor: SteelColors.danger), onPressed: () => Navigator.pop(ctx, true), child: Text(strings.get('remove')))])) ?? false;
    if (!ok) return;
    final successMessage = strings.get('machineDisabled');
    await _run(() async { await widget.controller.machinesApi.remove(machine.id); await widget.controller.loadMachines(); _message(successMessage); });
  }
  Future<void> _key(Machine machine) async {
    final strings = AppStrings.of(context);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(strings.get('generateNewKeyTitle')), content: Text(strings.get('generateNewKey')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.get('cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.get('generateNewKey')))])) ?? false;
    if (!ok) return;
    await _run(() async { final result = await widget.controller.machinesApi.regenerateKey(machine.id); await _showKey('${result['deviceKey'] ?? result['chave'] ?? ''}'); });
  }
  Future<void> _showKey(String key) => showDialog<void>(context: context, builder: (ctx) { final strings = AppStrings.of(ctx); return AlertDialog(icon: const Icon(Icons.key_rounded, color: SteelColors.primary, size: 40), title: Text(strings.get('deviceKey')), content: SelectableText(key, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800)), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(strings.get('understood')))]); });

  bool _maintenance(Machine machine) {
    final value = '${machine.status} ${machine.maintenanceStatus}'.toLowerCase();
    return value.contains('manuten') || value.contains('maintenance') || value.contains('wartung');
  }

  bool _alert(Machine machine) {
    final value = '${machine.status} ${machine.maintenanceStatus}'.toLowerCase();
    return machine.alerts.isNotEmpty || machine.safetyStop || value.contains('alert') || value.contains('crític') || value.contains('critic') || value.contains('falha');
  }

  String _typeOf(Machine machine) {
    final values = [machine.type, machine.controller, machine.model];
    return values.firstWhere((value) => value?.trim().isNotEmpty == true, orElse: () => 'Outro')!.trim();
  }

  bool _matchesStatus(Machine machine) => switch (_statusFilter) {
        'online' => machine.isOnline,
        'offline' => !machine.isOnline,
        'maintenance' => _maintenance(machine),
        'alert' => _alert(machine),
        _ => true,
      };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) => RefreshIndicator(onRefresh: widget.controller.loadMachines, child: LayoutBuilder(builder: (context, constraints) {
    final strings = AppStrings.of(context);
    final columns = constraints.maxWidth >= 1150 ? 3 : constraints.maxWidth >= 680 ? 2 : 1;
    final machines = widget.controller.machines;
    final types = machines.map(_typeOf).toSet().toList()..sort();
    if (_typeFilter != 'all' && !types.contains(_typeFilter)) _typeFilter = 'all';
    final query = _searchController.text.trim().toLowerCase();
    final filtered = machines.where((machine) {
      final searchable = [machine.name, machine.code, machine.model, machine.sector, machine.manufacturer ?? '', _typeOf(machine)].join(' ').toLowerCase();
      return (query.isEmpty || searchable.contains(query)) && (_typeFilter == 'all' || _typeOf(machine) == _typeFilter) && _matchesStatus(machine);
    }).toList();
    final operating = machines.where((machine) => machine.isOnline && !_maintenance(machine) && !_alert(machine)).length;
    final maintenance = machines.where(_maintenance).length;
    final alerts = machines.where(_alert).length;
    return CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
      SliverPadding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 12), sliver: SliverToBoxAdapter(child: _EquipmentHero(strings: strings))),
      SliverPadding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 12), sliver: SliverToBoxAdapter(child: _FleetMetrics(total: machines.length, operating: operating, maintenance: maintenance, alerts: alerts))),
      if (_admin) SliverPadding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 12), sliver: SliverToBoxAdapter(child: _EquipmentRegistrationCard(strings: strings, busy: _busy, onCreate: _create))),
      SliverPadding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 12), sliver: SliverToBoxAdapter(child: _MachinesToolbar(strings: strings, controller: _searchController, types: types, typeFilter: _typeFilter, statusFilter: _statusFilter, onSearch: (_) => setState(() {}), onType: (value) => setState(() => _typeFilter = value), onStatus: (value) => setState(() => _statusFilter = value)))),
      if (machines.isEmpty) SliverFillRemaining(hasScrollBody: false, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.precision_manufacturing_outlined, size: 60, color: SteelColors.muted), const SizedBox(height: 12), Text(strings.get('noMachinesCompany')), if (_admin) TextButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: Text(strings.get('firstMachine')))]))) else if (filtered.isEmpty) SliverPadding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 36), sliver: SliverToBoxAdapter(child: SectionCard(child: Padding(padding: const EdgeInsets.symmetric(vertical: 28), child: Center(child: Text(strings.get('noFilterResults'), style: const TextStyle(color: SteelColors.muted))))))) else SliverPadding(padding: const EdgeInsets.fromLTRB(22, 4, 22, 28), sliver: SliverGrid.builder(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 16, mainAxisSpacing: 16, mainAxisExtent: 468), itemCount: filtered.length, itemBuilder: (context, index) { final machine = filtered[index]; return _MachineCard(machine: machine, admin: _admin, onOpen: () async { await widget.controller.selectMachine(machine); widget.onSelected(); }, onEdit: () => _edit(machine), onRemove: () => _remove(machine), onKey: () => _key(machine)); })),
    ]);
  }));
}

class _EquipmentHero extends StatelessWidget {
  const _EquipmentHero({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0A1427), Color(0xFF13213D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: const Color(0xFF33435D)),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF071224).withValues(alpha: .18), blurRadius: 28, offset: const Offset(0, 12))],
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 650;
          final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(strings.get('companyEquipmentTitle'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -.8)),
            const SizedBox(height: 9),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Text(strings.get('companyEquipmentCaption'), style: const TextStyle(color: Color(0xFFCAD5E7), height: 1.5))),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, children: [strings.get('centralizedMonitoring'), strings.get('operationalHistory'), strings.get('integratedMaintenance')].map((label) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withValues(alpha: .15))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_rounded, size: 15, color: Color(0xFF43E58B)), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))]))).toList()),
          ]);
          if (!wide) return content;
          return Row(children: [Expanded(child: content), const SizedBox(width: 20), Container(width: 112, height: 112, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .07), border: Border.all(color: Colors.white.withValues(alpha: .18))), child: const Icon(Icons.settings_outlined, size: 48, color: Colors.white))]);
        }),
      );
}

class _FleetMetrics extends StatelessWidget {
  const _FleetMetrics({required this.total, required this.operating, required this.maintenance, required this.alerts});
  final int total;
  final int operating;
  final int maintenance;
  final int alerts;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final items = [
      (strings.get('equipmentCount'), total, Icons.precision_manufacturing_outlined, SteelColors.primary),
      (strings.get('inOperation'), operating, Icons.check_rounded, SteelColors.success),
      (strings.get('underMaintenance'), maintenance, Icons.build_rounded, SteelColors.warning),
      (strings.get('withAlert'), alerts, Icons.warning_amber_rounded, SteelColors.danger),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 850 ? 4 : constraints.maxWidth >= 460 ? 2 : 1;
      final ratio = columns == 1 ? 3.2 : columns == 2 ? 2.8 : 2.1;
      return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: ratio, children: items.map((item) => SectionCard(child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: item.$4.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(item.$3, color: item.$4)), const SizedBox(width: 13), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SteelColors.muted, fontSize: 11)), Text('${item.$2}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))]))]))).toList());
    });
  }
}

class _EquipmentRegistrationCard extends StatelessWidget {
  const _EquipmentRegistrationCard({required this.strings, required this.busy, required this.onCreate});
  final AppStrings strings;
  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => SectionCard(child: LayoutBuilder(builder: (context, constraints) {
        final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('equipmentManagement'), style: const TextStyle(color: SteelColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)), const SizedBox(height: 6), Text(strings.get('registerEquipmentTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(strings.get('registerEquipmentCaption'), style: const TextStyle(color: SteelColors.muted, fontSize: 12))]);
        final button = FilledButton.icon(onPressed: busy ? null : onCreate, icon: const Icon(Icons.add_rounded), label: Text(strings.get('newMachine')));
        if (constraints.maxWidth < 570) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [copy, const SizedBox(height: 16), button]);
        return Row(children: [Expanded(child: copy), const SizedBox(width: 18), button]);
      }));
}

class _MachinesToolbar extends StatelessWidget {
  const _MachinesToolbar({required this.strings, required this.controller, required this.types, required this.typeFilter, required this.statusFilter, required this.onSearch, required this.onType, required this.onStatus});
  final AppStrings strings;
  final TextEditingController controller;
  final List<String> types;
  final String typeFilter;
  final String statusFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onType;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(strings.get('industrialPark'), style: const TextStyle(color: SteelColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(strings.get('registeredEquipmentTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final search = TextField(controller: controller, onChanged: onSearch, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: strings.get('searchEquipment')));
          final type = DropdownButtonFormField<String>(initialValue: typeFilter, isExpanded: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)), items: [DropdownMenuItem(value: 'all', child: Text(strings.get('allTypes'))), ...types.map((value) => DropdownMenuItem(value: value, child: Text(value, overflow: TextOverflow.ellipsis)))], onChanged: (value) { if (value != null) onType(value); });
          final status = DropdownButtonFormField<String>(initialValue: statusFilter, isExpanded: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.tune_rounded)), items: [DropdownMenuItem(value: 'all', child: Text(strings.get('allStatuses'))), DropdownMenuItem(value: 'online', child: Text(strings.get('online'))), DropdownMenuItem(value: 'offline', child: Text(strings.get('offline'))), DropdownMenuItem(value: 'maintenance', child: Text(strings.get('underMaintenance'))), DropdownMenuItem(value: 'alert', child: Text(strings.get('withAlert')))], onChanged: (value) { if (value != null) onStatus(value); });
          if (constraints.maxWidth < 620) return Column(children: [search, const SizedBox(height: 10), type, const SizedBox(height: 10), status]);
          return Row(children: [Expanded(flex: 2, child: search), const SizedBox(width: 10), Expanded(child: type), const SizedBox(width: 10), Expanded(child: status)]);
        }),
      ]));
}

class _MachineCard extends StatelessWidget {
  const _MachineCard({required this.machine, required this.admin, required this.onOpen, required this.onEdit, required this.onRemove, required this.onKey});
  final Machine machine; final bool admin; final VoidCallback onOpen; final VoidCallback onEdit; final VoidCallback onRemove; final VoidCallback onKey;
  @override Widget build(BuildContext context) { final online = machine.isOnline; final strings = AppStrings.of(context); return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(width: 45, height: 45, decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(machine.isDobot ? Icons.precision_manufacturing_rounded : Icons.factory_outlined, color: SteelColors.primary)), const Spacer(), _Status(online: online)]),
    const SizedBox(height: 13), Text(machine.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${machine.sector} • ${strings.translate(machine.type ?? machine.controller ?? machine.model)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SteelColors.muted)),
    const SizedBox(height: 13), Row(children: [Expanded(child: _Detail(label: strings.get('manufacturer').toUpperCase(), value: machine.manufacturer?.isNotEmpty == true ? machine.manufacturer! : '-')), const SizedBox(width: 8), Expanded(child: _Detail(label: strings.get('model').toUpperCase(), value: machine.model))]), const SizedBox(height: 8), Row(children: [Expanded(child: _Detail(label: strings.get('code').toUpperCase(), value: machine.code)), const SizedBox(width: 8), Expanded(child: _Detail(label: strings.get('mode').toUpperCase(), value: machine.simulation ? strings.get('simulation') : strings.get('real')))]),
    const SizedBox(height: 10), Row(children: [Expanded(child: _Metric(icon: Icons.thermostat_rounded, value: '${machine.temperature.toStringAsFixed(1)}°C', label: strings.get('temperature'))), const SizedBox(width: 7), Expanded(child: _Metric(icon: Icons.loop_rounded, value: '${machine.cycles}', label: strings.get('cycles'))), const SizedBox(width: 7), Expanded(child: _Metric(icon: Icons.bolt_rounded, value: '${machine.energy.toStringAsFixed(0)}%', label: strings.get('load')))]),
    const Spacer(), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onOpen, icon: Icon(machine.isDobot ? Icons.precision_manufacturing_rounded : Icons.dashboard_outlined), label: Text(AppStrings.of(context).get(machine.isDobot ? 'openDobotPanel' : 'openPanel')))),
    if (admin) Row(children: [Expanded(child: OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: Text(strings.get('edit')))), const SizedBox(width: 7), IconButton.outlined(tooltip: strings.get('newKey'), onPressed: onKey, icon: const Icon(Icons.key_outlined)), const SizedBox(width: 7), IconButton.outlined(tooltip: strings.get('remove'), onPressed: onRemove, color: SteelColors.danger, icon: const Icon(Icons.delete_outline))]),
  ])); }
}

class _MachineDialog extends StatefulWidget {
  const _MachineDialog({this.machine});
  final Machine? machine;
  @override State<_MachineDialog> createState() => _MachineDialogState();
}

class _MachineDialogState extends State<_MachineDialog> {
  final key = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  bool simulation = true;
  bool identificationExpanded = false;
  bool networkExpanded = false;
  bool limitsExpanded = false;
  bool dobotAllowMotion = false;
  String controller = '';
  String protocol = '';
  String equipmentType = '';

  static const controllers = ['', 'ESP32', 'DOBOT_MAGICIAN', 'CLP_PLC', 'CONTROLADOR_ROBOTICO', 'CNC', 'GATEWAY_INDUSTRIAL', 'OUTRO'];
  static const protocols = ['', 'MODBUS_TCP', 'OPC_UA', 'MQTT', 'HTTP_REST', 'USB_SERIAL', 'TCP_IP', 'OUTRO'];
  static const equipmentTypes = ['', 'Braço robótico', 'Robô industrial', 'Esteira industrial', 'Prensa', 'Torno', 'Solda', 'Corte', 'Embalagem', 'CNC', 'Impressora 3D', 'Outro'];
  static const recommendedProtocols = <String, String>{
    'ESP32': 'HTTP_REST',
    'DOBOT_MAGICIAN': 'USB_SERIAL',
    'CLP_PLC': 'MODBUS_TCP',
    'CONTROLADOR_ROBOTICO': 'OPC_UA',
    'CNC': 'TCP_IP',
    'GATEWAY_INDUSTRIAL': 'MQTT',
  };

  @override
  void initState() {
    super.initState();
    final m = widget.machine;
    simulation = m?.simulation ?? true;
    final savedController = m?.controller == 'CONTROLADOR_CNC' ? 'CNC' : m?.controller ?? '';
    controller = controllers.contains(savedController) ? savedController : (savedController.isEmpty ? '' : 'OUTRO');
    final savedProtocol = m?.protocol ?? '';
    protocol = protocols.contains(savedProtocol) ? savedProtocol : (savedProtocol.isEmpty ? '' : 'OUTRO');
    equipmentType = m?.type ?? '';
    identificationExpanded = m != null && ((m.manufacturer?.isNotEmpty ?? false) || (m.type?.isNotEmpty ?? false) || (m.description?.isNotEmpty ?? false));
    networkExpanded = m != null && ((m.host?.isNotEmpty ?? false) || m.port != null || m.unitId != null || (m.endpoint?.isNotEmpty ?? false) || (m.topic?.isNotEmpty ?? false));
    final dobot = m?.integrationMeta['dobot'] as Map? ?? const {};
    dobotAllowMotion = dobot['allowMotion'] == true;
    final values = <String, dynamic>{
      'nome': m?.name,
      'setor': m?.sector,
      'modelo': m?.model,
      'codigo': m?.code,
      'fabricante': m?.manufacturer,
      'descricao': m?.description,
      'host': m?.host,
      'porta': m?.port,
      'unitId': m?.unitId,
      'endpoint': m?.endpoint,
      'topico': m?.topic,
      'intervaloLeitura': m?.readInterval ?? 2000,
      'tempAtencao': m?.temperatureWarning ?? 55,
      'tempCritica': m?.temperatureCritical ?? 70,
      'energiaAtencao': m?.energyWarning ?? 80,
      'energiaCritica': m?.energyCritical ?? 90,
      'vibracaoAtencao': m?.vibrationWarning ?? 4,
      'vibracaoCritica': m?.vibrationCritical ?? 7,
      'ciclosManutencao': m?.maintenanceCycles ?? 1000,
      'dobotMode': dobot['mode'] ?? 'MOCK',
      'dobotPort': dobot['port'] ?? 'AUTO',
    };
    for (final entry in values.entries) { fields[entry.key] = TextEditingController(text: entry.value?.toString() ?? ''); }
  }

  @override
  void dispose() { for (final value in fields.values) { value.dispose(); } super.dispose(); }

  Widget input(String name, String label, {IconData? icon, bool required = false, TextInputType? type, int lines = 1, String? hint}) => TextFormField(
        controller: fields[name], keyboardType: type, maxLines: lines,
        decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: icon == null ? null : Icon(icon, size: 20)),
        validator: required ? (v) => v?.trim().isNotEmpty == true ? null : AppStrings.of(context).get('requiredField') : null,
      );

  Widget pair(Widget first, Widget second) => LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 540) return Column(children: [first, const SizedBox(height: 12), second]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: first), const SizedBox(width: 12), Expanded(child: second)]);
      });

  String labelFor(String value) {
    const labels = {
      '': 'Configurar depois',
      'DOBOT_MAGICIAN': 'Dobot Magician',
      'CLP_PLC': 'CLP / PLC',
      'CONTROLADOR_ROBOTICO': 'Controlador robótico',
      'GATEWAY_INDUSTRIAL': 'Gateway industrial',
      'MODBUS_TCP': 'Modbus TCP',
      'OPC_UA': 'OPC UA',
      'HTTP_REST': 'HTTP / REST',
      'USB_SERIAL': 'USB / Serial',
      'TCP_IP': 'TCP/IP',
      'OUTRO': 'Outro',
    };
    return labels[value] ?? value;
  }

  void _useRobotTemplate() {
    final strings = AppStrings.of(context);
    fields['nome']!.text = strings.get('roboticArm');
    fields['setor']!.text = strings.get('automationSector');
    fields['modelo']!.text = 'ROB-01';
    fields['codigo']!.text = 'BR-${DateTime.now().millisecondsSinceEpoch.remainder(100000).toString().padLeft(5, '0')}';
    fields['fabricante']!.text = strings.get('toDefine');
    fields['descricao']!.text = strings.get('robotTemplateDescription');
    fields['dobotMode']!.text = 'MOCK';
    fields['dobotPort']!.text = 'AUTO';
    setState(() {
      equipmentType = 'Braço robótico';
      controller = 'DOBOT_MAGICIAN';
      protocol = 'USB_SERIAL';
      simulation = true;
      identificationExpanded = true;
    });
  }

  void _changeController(String value) {
    setState(() {
      controller = value;
      final recommended = recommendedProtocols[value];
      if (recommended != null && protocol.isEmpty) protocol = recommended;
      if (value == 'DOBOT_MAGICIAN') {
        protocol = 'USB_SERIAL';
      }
    });
  }

  double number(String name, double fallback) => double.tryParse(fields[name]?.text.replaceAll(',', '.') ?? '') ?? fallback;

  void _submit() {
    if (!key.currentState!.validate()) return;
    if (!simulation && controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).get('selectRealController')), backgroundColor: SteelColors.danger));
      return;
    }

    final tempWarning = number('tempAtencao', 55);
    final tempCritical = number('tempCritica', 70);
    final energyWarning = number('energiaAtencao', 80);
    final energyCritical = number('energiaCritica', 90);
    final vibrationWarning = number('vibracaoAtencao', 4);
    final vibrationCritical = number('vibracaoCritica', 7);
    final maintenanceCycles = int.tryParse(fields['ciclosManutencao']?.text ?? '') ?? 0;
    if (tempCritical <= tempWarning ||
        energyCritical <= energyWarning ||
        energyWarning < 0 ||
        energyCritical > 100 ||
        vibrationCritical <= vibrationWarning ||
        maintenanceCycles <= 0) {
      setState(() => limitsExpanded = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).get('reviewLimits')), backgroundColor: SteelColors.danger));
      return;
    }

    String? optional(String name) {
      final value = fields[name]?.text.trim() ?? '';
      return value.isEmpty ? null : value;
    }

    final data = <String, dynamic>{
      'nome': fields['nome']!.text.trim(),
      'setor': fields['setor']!.text.trim(),
      'modelo': fields['modelo']!.text.trim(),
      'codigo': fields['codigo']!.text.trim(),
      'fabricante': optional('fabricante'),
      'tipo': equipmentType.isEmpty ? null : equipmentType,
      'descricao': optional('descricao'),
      'controlador': controller.isEmpty ? null : controller,
      'protocolo': protocol.isEmpty ? null : protocol,
      'modoSimulacao': simulation,
      'host': optional('host'),
      'porta': int.tryParse(fields['porta']?.text ?? ''),
      'unitId': int.tryParse(fields['unitId']?.text ?? ''),
      'endpoint': optional('endpoint'),
      'topico': optional('topico'),
      'intervaloLeitura': int.tryParse(fields['intervaloLeitura']?.text ?? '') ?? 2000,
      'tempAtencao': tempWarning,
      'tempCritica': tempCritical,
      'energiaAtencao': energyWarning,
      'energiaCritica': energyCritical,
      'vibracaoAtencao': vibrationWarning,
      'vibracaoCritica': vibrationCritical,
      'ciclosManutencao': maintenanceCycles,
      'integracaoMeta': controller == 'DOBOT_MAGICIAN'
          ? {
              'dobot': {
                'enabled': true,
                'mode': fields['dobotMode']!.text.trim().toUpperCase(),
                'port': fields['dobotPort']!.text.trim().toUpperCase(),
                'baudRate': 115200,
                'allowMotion': dobotAllowMotion,
                'externalSensors': {'temperature': false, 'vibration': false, 'current': false},
              }
            }
          : null,
    };
    Navigator.pop(context, data);
  }

  Widget disclosure({required String title, required String caption, required IconData icon, required bool expanded, required VoidCallback onTap, required Widget child}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: colors.surfaceContainerLowest, border: Border.all(color: expanded ? SteelColors.primary.withValues(alpha: .45) : Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: SteelColors.primary, size: 19)),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), const SizedBox(height: 2), Text(caption, style: const TextStyle(color: SteelColors.muted, fontSize: 10))])),
              AnimatedRotation(turns: expanded ? .5 : 0, duration: const Duration(milliseconds: 180), child: const Icon(Icons.keyboard_arrow_down_rounded, color: SteelColors.muted)),
            ]),
          ),
        ),
        AnimatedSize(duration: const Duration(milliseconds: 180), curve: Curves.easeOut, child: expanded ? Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 16), child: child) : const SizedBox.shrink()),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.machine != null;
    final size = MediaQuery.sizeOf(context);
    final strings = AppStrings.of(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: size.width < 700 ? 12 : 32, vertical: 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 840, maxHeight: size.height * .94),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 18, 20),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [SteelColors.ink, Color(0xFF1D4ED8)]), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.precision_manufacturing_rounded, color: Colors.white)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(editing ? strings.get('editEquipment') : strings.get('registerEquipment'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(strings.get('registerEquipmentCaption'), style: const TextStyle(color: Colors.white70, fontSize: 12))])),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
            ]),
          ),
          Expanded(
            child: Form(
              key: key,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .07), border: Border.all(color: SteelColors.primary.withValues(alpha: .18)), borderRadius: BorderRadius.circular(15)), child: Row(children: [const Icon(Icons.verified_outlined, color: SteelColors.primary), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('quickRegistration'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), const SizedBox(height: 2), Text(strings.get('quickRegistrationCaption'), style: const TextStyle(color: SteelColors.muted, fontSize: 10))]))])),
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(15)), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.precision_manufacturing_rounded, color: SteelColors.primary)), const SizedBox(width: 11), Expanded(child: Text(strings.get('robotTemplateQuestion'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))), OutlinedButton.icon(onPressed: _useRobotTemplate, icon: const Icon(Icons.auto_fix_high_rounded, size: 17), label: Text(strings.get('useTemplate')))])),
                  const SizedBox(height: 24),
                  _FormSection(icon: Icons.badge_outlined, number: '01', title: strings.get('equipmentIdentification'), caption: strings.get('essentialPanelData')),
                  const SizedBox(height: 16),
                  pair(input('nome',strings.get('machineName'),icon:Icons.precision_manufacturing_outlined,required:true), input('setor',strings.get('sector'),icon:Icons.account_tree_outlined,required:true)),
                  const SizedBox(height: 12),
                  pair(input('modelo',strings.get('model'),icon:Icons.inventory_2_outlined,required:true), input('codigo',strings.get('internalCode'),icon:Icons.qr_code_rounded,required:true)),
                  const SizedBox(height: 12),
                  disclosure(title: identificationExpanded ? strings.get('hideDetails') : strings.get('additionalDetails'), caption: strings.get('operationalDescription'), icon: Icons.tune_rounded, expanded: identificationExpanded, onTap: () => setState(() => identificationExpanded = !identificationExpanded), child: Column(children: [
                    pair(
                      DropdownButtonFormField<String>(key: ValueKey(equipmentType), initialValue: equipmentTypes.contains(equipmentType) ? equipmentType : 'Outro', decoration: InputDecoration(labelText: strings.get('equipmentType'), prefixIcon: const Icon(Icons.category_outlined)), items: equipmentTypes.map((value) => DropdownMenuItem(value: value, child: Text(value.isEmpty ? strings.get('configureLater') : strings.translate(value)))).toList(), onChanged: (value) => equipmentType = value ?? ''),
                      input('fabricante',strings.get('manufacturer'),icon:Icons.factory_outlined,hint:'ABB, KUKA, FANUC...'),
                    ),
                    const SizedBox(height: 12),
                    input('descricao',strings.get('operationalDescription'),icon:Icons.notes_rounded,lines:3),
                  ])),
                  const SizedBox(height: 25),
                  _FormSection(icon: Icons.settings_input_component_outlined, number: '02', title: strings.get('operationMode'), caption: strings.get('simulationCaption')),
                  const SizedBox(height: 15),
                  Row(children: [Expanded(child: _ModeCard(title:strings.get('simulation'),caption:strings.get('simulationCaption'),icon:Icons.science_outlined,selected:simulation,onTap:()=>setState(()=>simulation=true))),const SizedBox(width:12),Expanded(child:_ModeCard(title:strings.get('real'),caption:strings.get('realTelemetryCaption'),icon:Icons.memory_rounded,selected:!simulation,onTap:()=>setState(()=>simulation=false)))]),
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (simulation ? SteelColors.primary : SteelColors.warning).withValues(alpha: .08), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(simulation ? Icons.science_outlined : Icons.info_outline_rounded, color: simulation ? SteelColors.primary : SteelColors.warning, size: 19), const SizedBox(width: 9), Expanded(child: Text(simulation ? strings.get('simulationGenerated') : strings.get('realStaysOffline'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))])),
                  const SizedBox(height: 25),
                  _FormSection(icon: Icons.lan_outlined, number: '03', title: strings.get('industrialCommunication'), caption: strings.get('communicationCaption')),
                  const SizedBox(height: 16),
                  pair(
                    DropdownButtonFormField<String>(key: ValueKey(controller), initialValue: controllers.contains(controller) ? controller : 'OUTRO', decoration: InputDecoration(labelText:strings.get('controllerGateway'),prefixIcon:const Icon(Icons.hub_outlined)), items: controllers.map((value)=>DropdownMenuItem(value:value,child:Text(value.isEmpty?strings.get('select'):strings.translate(labelFor(value))))).toList(), onChanged:(value)=>_changeController(value??''), validator: (value) => !simulation && (value?.isEmpty ?? true) ? strings.get('realModeRequired') : null),
                    DropdownButtonFormField<String>(key: ValueKey(protocol), initialValue: protocols.contains(protocol) ? protocol : 'OUTRO', decoration: InputDecoration(labelText:strings.get('protocol'),prefixIcon:const Icon(Icons.swap_horiz_rounded)), items: protocols.map((value)=>DropdownMenuItem(value:value,child:Text(value.isEmpty?strings.get('configureLater'):strings.translate(labelFor(value))))).toList(), onChanged:(value)=>setState(()=>protocol=value??'')),
                  ),
                  if (controller == 'DOBOT_MAGICIAN') ...[
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: SteelColors.primary.withValues(alpha: .06), border: Border.all(color: SteelColors.primary.withValues(alpha: .20)), borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [const Icon(Icons.precision_manufacturing_rounded, color: SteelColors.primary), const SizedBox(width: 9), Text(strings.get('dobotGateway'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
                      const SizedBox(height: 12),
                      pair(input('dobotMode',strings.get('gatewayMode'),icon:Icons.settings_ethernet_rounded,hint:'MOCK / REAL'), input('dobotPort',strings.get('serialPort'),icon:Icons.usb_rounded,hint:'AUTO / COM4')),
                      SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: Text(strings.get('preparePhysicalControl'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)), subtitle: Text(strings.get('physicalControlCaption'), style: const TextStyle(fontSize: 10)), value: dobotAllowMotion, onChanged: (value) => setState(() => dobotAllowMotion = value)),
                    ])),
                  ],
                  const SizedBox(height: 12),
                  disclosure(title: networkExpanded ? strings.get('hideAdvancedNetwork') : strings.get('advancedNetwork'), caption: strings.get('readingInterval'), icon: Icons.network_check_rounded, expanded: networkExpanded, onTap: () => setState(() => networkExpanded = !networkExpanded), child: Column(children: [
                    pair(input('host',strings.get('host'),icon:Icons.dns_outlined,hint:'192.168.0.50'), input('porta',strings.get('port'),icon:Icons.numbers_rounded,type:TextInputType.number)),
                    const SizedBox(height: 12),
                    pair(input('unitId',strings.get('unitId'),icon:Icons.tag_rounded,type:TextInputType.number), input('intervaloLeitura',strings.get('readingInterval'),icon:Icons.timer_outlined,type:TextInputType.number)),
                    const SizedBox(height: 12),
                    input('endpoint',strings.get('endpointPath'),icon:Icons.link_rounded,hint:'/api/telemetria'),
                    const SizedBox(height: 12),
                    input('topico',strings.get('mqttTopic'),icon:Icons.podcasts_rounded,hint:'factory/robot01/telemetry'),
                  ])),
                  const SizedBox(height: 25),
                  _FormSection(icon: Icons.shield_outlined, number: '04', title: strings.get('operationalLimits'), caption: strings.get('recommendedValues')),
                  const SizedBox(height: 14),
                  disclosure(title: limitsExpanded ? strings.get('recommendedLimits') : strings.get('customizeLimits'), caption: strings.get('operationalLimits'), icon: Icons.health_and_safety_outlined, expanded: limitsExpanded, onTap: () => setState(() => limitsExpanded = !limitsExpanded), child: Column(children: [
                    pair(input('tempAtencao',strings.get('temperatureWarning'),icon:Icons.thermostat_outlined,type:TextInputType.number), input('tempCritica',strings.get('criticalTemperature'),icon:Icons.device_thermostat_rounded,type:TextInputType.number)),
                    const SizedBox(height: 12),
                    pair(input('energiaAtencao',strings.get('loadWarning'),icon:Icons.bolt_outlined,type:TextInputType.number), input('energiaCritica',strings.get('criticalLoad'),icon:Icons.warning_amber_rounded,type:TextInputType.number)),
                    const SizedBox(height: 12),
                    pair(input('vibracaoAtencao',strings.get('vibrationWarning'),icon:Icons.waves_outlined,type:TextInputType.number), input('vibracaoCritica',strings.get('criticalVibration'),icon:Icons.vibration_rounded,type:TextInputType.number)),
                    const SizedBox(height: 12),
                    input('ciclosManutencao',strings.get('preventiveCycles'),icon:Icons.loop_rounded,type:TextInputType.number),
                  ])),
                ]),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed:()=>Navigator.pop(context),child:Text(strings.get('cancel'))),const SizedBox(width:8),FilledButton.icon(onPressed:_submit,icon:Icon(editing?Icons.save_outlined:Icons.add_rounded),label:Text(editing?strings.get('saveChanges'):strings.get('registerEquipment')))]),
          ),
        ]),
      ),
    );
  }
}

class _FormSection extends StatelessWidget { const _FormSection({required this.icon,required this.number,required this.title,required this.caption}); final IconData icon; final String number,title,caption; @override Widget build(BuildContext context)=>Row(children:[Container(width:43,height:43,decoration:BoxDecoration(color:SteelColors.primary.withValues(alpha:.09),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:SteelColors.primary,size:21)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$number  $title',style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),const SizedBox(height:2),Text(caption,style:const TextStyle(color:SteelColors.muted,fontSize:11))]))]); }
class _ModeCard extends StatelessWidget { const _ModeCard({required this.title,required this.caption,required this.icon,required this.selected,required this.onTap}); final String title,caption; final IconData icon; final bool selected; final VoidCallback onTap; @override Widget build(BuildContext context)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(16),child:AnimatedContainer(duration:const Duration(milliseconds:180),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:selected?SteelColors.primary.withValues(alpha:.09):Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha:.35),border:Border.all(color:selected?SteelColors.primary:Theme.of(context).dividerColor,width:selected?1.5:1),borderRadius:BorderRadius.circular(16)),child:Row(children:[Container(width:40,height:40,decoration:BoxDecoration(color:selected?SteelColors.primary:SteelColors.muted.withValues(alpha:.1),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:selected?Colors.white:SteelColors.muted,size:20)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13)),const SizedBox(height:2),Text(caption,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:SteelColors.muted,fontSize:10))])),Icon(selected?Icons.check_circle_rounded:Icons.circle_outlined,color:selected?SteelColors.primary:SteelColors.muted,size:19)]))); }

class _Status extends StatelessWidget { const _Status({required this.online}); final bool online; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:(online?SteelColors.success:SteelColors.danger).withValues(alpha:.10),borderRadius:BorderRadius.circular(99)),child:Row(children:[Icon(Icons.circle,size:8,color:online?SteelColors.success:SteelColors.danger),const SizedBox(width:6),Text(AppStrings.of(context).get(online?'online':'offline'),style:TextStyle(color:online?SteelColors.success:SteelColors.danger,fontSize:11,fontWeight:FontWeight.w800))])); }
class _Detail extends StatelessWidget { const _Detail({required this.label,required this.value}); final String label,value; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerLowest,border:Border.all(color:Theme.of(context).dividerColor),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:SteelColors.muted,fontSize:9,fontWeight:FontWeight.w700)),const SizedBox(height:2),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800))])); }
class _Metric extends StatelessWidget { const _Metric({required this.icon,required this.value,required this.label}); final IconData icon; final String value,label; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(vertical:9,horizontal:5),decoration:BoxDecoration(color:SteelColors.primary.withValues(alpha:.07),borderRadius:BorderRadius.circular(10)),child:Column(children:[Icon(icon,size:16,color:SteelColors.primary),const SizedBox(height:2),Text(value,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)),Text(label,style:const TextStyle(fontSize:8,color:SteelColors.muted))])); }

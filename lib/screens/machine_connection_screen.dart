import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_strings.dart';
import '../services/api_client.dart';

class MachineConnectionScreen extends StatefulWidget {
  const MachineConnectionScreen({
    required this.client,
    required this.machineId,
    required this.machineName,
    this.controller,
    this.protocol,
    super.key,
  });
  final ApiClient client;
  final int machineId;
  final String machineName;
  final String? controller;
  final String? protocol;
  @override
  State<MachineConnectionScreen> createState() =>
      _MachineConnectionScreenState();
}

class _MachineConnectionScreenState extends State<MachineConnectionScreen> {
  static const drivers = <String, String>{
    'AUTO': 'edgeAuto',
    'DOBOT_MAGICIAN': 'Dobot Magician (USB)',
    'SERIAL_JSON': 'USB / serial JSON',
    'MODBUS_RTU': 'Modbus RTU',
    'MODBUS_TCP': 'Modbus TCP',
    'OPC_UA': 'OPC UA',
    'MQTT': 'MQTT',
    'HTTP_REST': 'HTTP / REST',
    'TCP_IP': 'TCP / IP JSON',
    'MOCK': 'edgeSimulator',
  };
  final _host = TextEditingController(),
      _port = TextEditingController(),
      _baud = TextEditingController(text: '115200'),
      _unit = TextEditingController(text: '1'),
      _endpoint = TextEditingController(),
      _topic = TextEditingController(),
      _advanced = TextEditingController();
  List<Map<String, dynamic>> _computers = [];
  List<Map<String, dynamic>> _adapters = [];
  Map<String, dynamic> _capabilities = {};
  String? _hostId, _serialPort;
  String _driver = 'AUTO', _status = '';
  String _t(String key) => AppStrings.of(context).get(key);
  bool _busy = false, _loading = true, _commands = false, _refreshing = false;
  Timer? _timer;
  String get _path => '/conexoes/maquinas/${widget.machineId}';
  @override
  void initState() {
    super.initState();
    final preferred = widget.controller == 'DOBOT_MAGICIAN'
        ? 'DOBOT_MAGICIAN'
        : widget.protocol == 'USB_SERIAL'
        ? 'SERIAL_JSON'
        : widget.protocol;
    if (drivers.containsKey(preferred)) _driver = preferred!;
    _load(initial: true);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_busy) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [
      _host,
      _port,
      _baud,
      _unit,
      _endpoint,
      _topic,
      _advanced,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final computers =
          await widget.client.get('/conexoes/computadores') as Map;
      final data = await widget.client.get(_path) as Map;
      if (initial) {
        final catalog = await widget.client.get('/conexoes/adaptadores') as Map;
        _adapters = (catalog['adaptadores'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (!mounted) return;
      final list = (computers['computadores'] as List? ?? [])
          .whereType<Map>()
          .where((h) => h['tipo'] != 'NAVEGADOR')
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final rawConnection = data['conexao'];
      final connection =
          rawConnection is Map && rawConnection['tipo'] != 'NAVEGADOR'
          ? rawConnection
          : null;
      setState(() {
        _computers = list;
        _capabilities = Map<String, dynamic>.from(
          data['capacidades'] as Map? ?? {},
        );
        if (initial && connection is Map) {
          _hostId = '${connection['hostId']}';
          final configuredDriver = '${connection['driver']}';
          if (drivers.containsKey(configuredDriver)) _driver = configuredDriver;
          _commands = connection['comandos'] == true;
          final p = Map<String, dynamic>.from(
            connection['parametros'] as Map? ?? {},
          );
          _serialPort = p['serialPort']?.toString();
          for (final entry in {
            'host': _host,
            'port': _port,
            'baud': _baud,
            'unitId': _unit,
            'endpoint': _endpoint,
            'topic': _topic,
          }.entries) {
            if (p[entry.key] != null) entry.value.text = '${p[entry.key]}';
          }
          p.removeWhere(
            (key, _) => [
              'serialPort',
              'host',
              'port',
              'baud',
              'unitId',
              'endpoint',
              'topic',
            ].contains(key),
          );
          _advanced.text = p.isEmpty
              ? ''
              : const JsonEncoder.withIndent('  ').convert(p);
        }
        if (initial && _hostId == null && list.length == 1)
          _hostId = '${list.first['id']}';
        if (!list.any((h) => '${h['id']}' == _hostId)) _hostId = null;
        final selected = list.where((h) => '${h['id']}' == _hostId).firstOrNull;
        final ports = (selected?['portas'] as List? ?? []).whereType<Map>();
        if (!ports.any((p) => p['porta'] == _serialPort)) _serialPort = null;
        const states = {
          'ONLINE': 'edgeConnected',
          'CONNECTING': 'edgeConnecting',
          'ERROR': 'edgeError',
          'STOPPED': 'edgeStopped',
          'OFFLINE': 'edgeOffline',
        };
        _status = connection is Map
            ? '${_t(states[connection['estado']] ?? 'edgeUnknown')} · ${connection['computador']}'
            : list.isEmpty
            ? _t('edgeNoComputer')
            : _t('edgeSelectComputer');
        _loading = false;
      });
    } catch (e) {
      if (e is ApiException && e.statusCode == 404 && mounted) {
        Navigator.maybePop(context);
        return;
      }
      if (mounted)
        setState(() {
          _status = e is ApiException ? e.message : _t('edgeLoadFailed');
          _loading = false;
        });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final selected = _computers
        .where((h) => '${h['id']}' == _hostId)
        .firstOrNull;
    String? validation;
    if (selected == null) {
      validation = _t('edgeSelectComputer');
    } else if (selected['online'] != true) {
      validation = _t('edgeOpenComputer');
    } else if (_capabilities['situacao'] == 'SIMULACAO') {
      validation = _t('edgeRealRequired');
    } else if ([
          'DOBOT_MAGICIAN',
          'SERIAL_JSON',
          'MODBUS_RTU',
        ].contains(_driver) &&
        !(selected['portas'] as List? ?? []).whereType<Map>().any(
          (p) => p['porta'] == _serialPort,
        )) {
      validation = _t('edgeSelectPort');
    }
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation),
          backgroundColor: SteelColors.danger,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      Map<String, dynamic> params = {};
      if (_advanced.text.trim().isNotEmpty) {
        final decoded = jsonDecode(_advanced.text);
        if (decoded is! Map) throw FormatException(_t('edgeJsonObject'));
        params = Map<String, dynamic>.from(decoded);
      }
      for (final e in {
        'host': _host,
        'port': _port,
        'baud': _baud,
        'unitId': _unit,
        'endpoint': _endpoint,
        'topic': _topic,
      }.entries) {
        final relevant = switch (e.key) {
          'host' || 'port' => [
            'AUTO',
            'MODBUS_TCP',
            'MQTT',
            'TCP_IP',
            'HTTP_REST',
            'OPC_UA',
          ].contains(_driver),
          'baud' => [
            'AUTO',
            'DOBOT_MAGICIAN',
            'SERIAL_JSON',
            'MODBUS_RTU',
          ].contains(_driver),
          'unitId' => ['AUTO', 'MODBUS_TCP', 'MODBUS_RTU'].contains(_driver),
          'endpoint' => ['AUTO', 'OPC_UA', 'HTTP_REST'].contains(_driver),
          'topic' => ['AUTO', 'MQTT'].contains(_driver),
          _ => false,
        };
        if (!relevant) continue;
        if (e.value.text.trim().isNotEmpty)
          params[e.key] = ['port', 'baud', 'unitId'].contains(e.key)
              ? int.parse(e.value.text.trim())
              : e.value.text.trim();
      }
      if ([
        'AUTO',
        'DOBOT_MAGICIAN',
        'SERIAL_JSON',
        'MODBUS_RTU',
      ].contains(_driver)) {
        params.remove('serialPort');
        if (_serialPort != null) params['serialPort'] = _serialPort;
      }
      final result = await widget.client.put(
        _path,
        body: {
          'hostId': _hostId,
          'driver': _driver,
          'parametros': params,
          'comandos': _commands,
        },
      ) as Map;
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${result['mensagem']}')));
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : _t('edgeCheckFields'),
            ),
            backgroundColor: SteelColors.danger,
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    if (_busy) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('edgeDisconnectTitle')),
        content: Text(_t('edgeDisconnectCaption')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('edgeDisconnect')),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.client.delete(_path);
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : _t('edgeDisconnectFailed'),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      enabled: !_busy,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final selected = _computers
        .where((h) => '${h['id']}' == _hostId)
        .firstOrNull;
    final canSave =
        selected?['online'] == true && _capabilities['situacao'] != 'SIMULACAO';
    final monitoring = _capabilities['monitoramento'] as Map? ?? {};
    final control = _capabilities['controle'] as Map? ?? {};
    final serial = [
      'AUTO',
      'DOBOT_MAGICIAN',
      'SERIAL_JSON',
      'MODBUS_RTU',
    ].contains(_driver);
    final network = [
      'AUTO',
      'MODBUS_TCP',
      'MQTT',
      'TCP_IP',
      'HTTP_REST',
      'OPC_UA',
    ].contains(_driver);
    final ports = (selected?['portas'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final validPort = ports.any((p) => p['porta'] == _serialPort)
        ? _serialPort
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('edgeConnection')),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh),
            tooltip: _t('retry'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.machineName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.settings_input_component_outlined,
                          color: SteelColors.industrialAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _status.isEmpty ? _t('edgeLoading') : _status,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_t('edgeRegistration')),
                        const SizedBox(height: 8),
                        Text(
                          "${_t('edgeMonitoring')}: ${_t(_capabilities['situacao'] == 'SIMULACAO'
                              ? 'simulation'
                              : monitoring['confirmado'] == true
                              ? 'edgeConfirmed'
                              : 'edgeWaiting')}",
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${_t('edgeControl')}: ${_t(control['habilitado'] == true ? 'edgeControlAllowed' : 'edgeBlocked')}",
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_computers.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(_t('edgeInstructions')),
                  ),
                if (selected != null && selected['online'] != true)
                  Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(_t('edgeOpenComputer')),
                  ),
                if (serial && selected?['online'] == true && ports.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(_t('edgeNoPorts')),
                  ),
                if (_capabilities['situacao'] == 'SIMULACAO')
                  Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(_t('edgeRealRequired')),
                  ),
                DropdownButtonFormField<String>(
                  value: _hostId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: _t('edgeComputer')),
                  items: _computers
                      .map(
                        (h) => DropdownMenuItem<String>(
                          value: '${h['id']}',
                          child: Text(
                            '${h['nome']}${h['online'] == true ? '' : ' — offline'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _hostId = v;
                          _serialPort = null;
                        }),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _driver,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: _t('edgeProtocol')),
                  items: drivers.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            e.key == 'AUTO' || e.key == 'MOCK'
                                ? _t(e.value)
                                : e.value,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _driver = v ?? 'AUTO'),
                ),
                const SizedBox(height: 14),
                if (serial) ...[
                  DropdownButtonFormField<String>(
                    key: const ValueKey('connectionPort'),
                    value: validPort,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _t('edgeSerialPort'),
                    ),
                    items: ports
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: '${p['porta']}',
                            child: Text(
                              '${p['porta']} — ${p['nome']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _serialPort = v),
                  ),
                  const SizedBox(height: 14),
                  _input(_t('edgeBaud'), _baud, number: true),
                ],
                if (network) ...[
                  _input('IP / host', _host),
                  _input(_t('edgeNetworkPort'), _port, number: true),
                ],
                if (['AUTO', 'MODBUS_TCP', 'MODBUS_RTU'].contains(_driver))
                  _input('Unit ID (Modbus)', _unit, number: true),
                if (['AUTO', 'OPC_UA', 'HTTP_REST'].contains(_driver))
                  _input('Endpoint', _endpoint),
                if (['AUTO', 'MQTT'].contains(_driver))
                  _input(_t('edgeTopic'), _topic),
                ExpansionTile(
                  title: Text(_t('edgeAdapters')),
                  children: _adapters
                      .map(
                        (a) => ListTile(
                          title: Text('${a['nome']}'),
                          subtitle: Text('${a['observacao'] ?? ''}'),
                        ),
                      )
                      .toList(),
                ),
                ExpansionTile(
                  title: Text(_t('edgeAdvanced')),
                  children: [
                    TextField(
                      controller: _advanced,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: _t('edgeParameters'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_t('edgeCommands')),
                  subtitle: Text(_t('edgePermissions')),
                  value: _commands,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _commands = v),
                ),
                Text(_t('edgeKeepOn')),
                Text(_t('edgePhysicalStop')),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('saveConnection'),
                  onPressed: _busy || !canSave ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cable),
                  label: Text(_t('edgeSave')),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : _disconnect,
                  child: Text(_t('edgeDisconnect')),
                ),
              ],
            ),
    );
  }
}

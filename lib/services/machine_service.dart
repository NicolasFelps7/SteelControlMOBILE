import 'package:flutter/foundation.dart';

import '../models/machine.dart';
import 'api_client.dart';

class MachineSyncSnapshot {
  const MachineSyncSnapshot({
    required this.companyId,
    required this.userId,
    required this.machines,
  });

  final int companyId;
  final int userId;
  final List<Machine> machines;
}

class MachineService {
  MachineService(this.client);

  final ApiClient client;

  List<Machine> _parseMachines(dynamic result) {
    final List<dynamic> items;
    if (result is List) {
      items = result;
    } else if (result is Map) {
      final raw = result['maquinas'] ?? result['items'] ?? result['dados'];
      items = raw is List ? raw : const <dynamic>[];
    } else {
      items = const <dynamic>[];
    }

    return items
        .whereType<Map>()
        .map((json) => Machine.fromJson(Map<String, dynamic>.from(json)))
        .where((machine) => machine.id > 0)
        .toList(growable: false);
  }

  Future<MachineSyncSnapshot> sync() async {
    // Usa o endpoint estável que existe em todas as versões atuais do
    // SteelControl Desktop. A Central de Máquinas não depende de uma rota
    // auxiliar para conseguir listar equipamentos.
    final result = await client.get('/maquinas');
    final machines = _parseMachines(result);
    if (kDebugMode) {
      final ids = machines.map((machine) => machine.id).join(',');
      debugPrint('[SteelControl][machines] GET /maquinas -> ${machines.length} item(ns) [${ids.isEmpty ? '-' : ids}]');
    }

    // A identificação da empresa é apenas diagnóstica. Uma falha não deve
    // esconder uma lista de máquinas que já foi carregada com sucesso.
    var companyId = 0;
    try {
      final companyResult = await client.get('/empresa/me');
      if (companyResult is Map) {
        final map = Map<String, dynamic>.from(companyResult);
        final company = map['empresa'];
        companyId = company is Map
            ? _intValue(company['id'])
            : _intValue(map['id']);
      }
    } on ApiException catch (exception) {
      // Sessão inválida continua sendo tratada pelo AppController.
      if (exception.statusCode == 401) rethrow;
      // Para qualquer outra falha de /empresa/me, preserva a lista já
      // recebida em /maquinas e usa o empresaId da sessão como fallback.
    }

    return MachineSyncSnapshot(
      companyId: companyId,
      userId: 0,
      machines: machines,
    );
  }

  Future<List<Machine>> list() async => (await sync()).machines;

  Future<Machine> find(int id) async {
    final result = await client.get('/maquinas/$id');
    return Machine.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Stream<Map<String, dynamic>> events(int id) => client.sse('/maquinas/$id/stream');

  Future<List<MaintenanceRecord>> maintenance(int machineId) async {
    final result = await client.get('/maquinas/$machineId/manutencoes') as List;
    return result
        .whereType<Map>()
        .map((json) => MaintenanceRecord.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<void> createMaintenance({
    required int machineId,
    required String type,
    required String technician,
    required String description,
  }) async {
    await client.post(
      '/maquinas/$machineId/manutencoes',
      body: {
        'tipo': type,
        'tecnico': technician,
        'descricao': description,
      },
    );
  }

  Future<void> removeMaintenance(int machineId, int maintenanceId) async {
    await client.delete('/maquinas/$machineId/manutencoes/$maintenanceId');
  }

  Future<Machine> simulate(int id) async {
    final result = await client.post('/maquinas/$id/simular');
    return Machine.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<Machine> runScenario(int id, String scenario) async {
    final result = await client.post(
      '/maquinas/$id/demonstracao',
      body: {'cenario': scenario},
    );
    return Machine.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<Map<String, dynamic>> diagnostics(int id) async {
    final result = await client.get('/maquinas/$id/diagnostico');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> telemetry(int id, {int limit = 60}) async {
    final result = await client.get(
      '/maquinas/$id/telemetria',
      query: {'limit': limit},
    ) as List;
    return result.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> sendDobotCommand(int id, String command, [Map<String, dynamic>? data]) async {
    await client.post(
      '/maquinas/$id/comandos',
      body: {'comando': command, 'payload': data ?? <String, dynamic>{}},
    );
  }

  Future<Map<String, dynamic>> sendHmiCommand(int id, String command) async {
    final result = await client.post(
      '/maquinas/$id/ihm/comandos',
      body: {'comando': command},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> discoveredDevices() async {
    final result = await client.get('/descoberta') as List;
    return result.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> scanDiscovery() async {
    await client.post('/descoberta/varrer');
  }

  Future<Map<String, dynamic>> discoveryDiagnostics() async {
    final result = await client.get('/descoberta/diagnostico');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> discoverDeviceByIp(String host, {int port = 80}) async {
    final result = await client.post(
      '/descoberta/por-ip',
      body: <String, dynamic>{'host': host, 'port': port},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> approveDiscoveredDevice(String discoveryId) async {
    final encoded = Uri.encodeComponent(discoveryId);
    final result = await client.post('/descoberta/$encoded/aprovar', body: <String, dynamic>{});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(await client.post('/maquinas', body: data) as Map);

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(await client.put('/maquinas/$id', body: data) as Map);

  Future<void> remove(int id) => client.delete('/maquinas/$id');

  Future<Map<String, dynamic>> regenerateKey(int id) async => Map<String, dynamic>.from(
        await client.post('/maquinas/$id/device-key/regenerar') as Map,
      );
}

int _intValue(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

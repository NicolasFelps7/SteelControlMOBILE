class Machine {
  const Machine({
    required this.id,
    required this.name,
    required this.sector,
    required this.model,
    required this.code,
    required this.status,
    required this.temperature,
    required this.vibration,
    required this.current,
    required this.production,
    required this.cycles,
    required this.energy,
    required this.simulation,
    required this.connection,
    required this.safetyStop,
    this.controller,
    this.protocol,
    this.maintenanceStatus = 'Normal',
    this.lastMaintenance = 'Sem registro',
    this.nextMaintenance = 'A definir',
    this.logs = const [],
    this.alerts = const [],
    this.extraData = const {},
    this.manufacturer,
    this.type,
    this.description,
    this.host,
    this.endpoint,
    this.topic,
    this.port,
    this.unitId,
    this.readInterval = 2000,
    this.temperatureWarning = 55,
    this.temperatureCritical = 70,
    this.energyWarning = 80,
    this.energyCritical = 90,
    this.vibrationWarning = 4,
    this.vibrationCritical = 7,
    this.maintenanceCycles = 1000,
    this.integrationMeta = const {},
    this.signalQuality,
    this.latencyMs,
  });

  final int id;
  final String name;
  final String sector;
  final String model;
  final String code;
  final String status;
  final double temperature;
  final double vibration;
  final double current;
  final int production;
  final int cycles;
  final double energy;
  final bool simulation;
  final String connection;
  final bool safetyStop;
  final String? controller;
  final String? protocol;
  final String maintenanceStatus;
  final String lastMaintenance;
  final String nextMaintenance;
  final List<String> logs;
  final List<MachineAlert> alerts;
  final Map<String, dynamic> extraData;
  final String? manufacturer;
  final String? type;
  final String? description;
  final String? host;
  final String? endpoint;
  final String? topic;
  final int? port;
  final int? unitId;
  final int readInterval;
  final double temperatureWarning;
  final double temperatureCritical;
  final double energyWarning;
  final double energyCritical;
  final double vibrationWarning;
  final double vibrationCritical;
  final int maintenanceCycles;
  final Map<String, dynamic> integrationMeta;
  final double? signalQuality;
  final double? latencyMs;

  bool get isOnline {
    final normalized = connection.toLowerCase();
    return simulation || normalized == 'online' || normalized == 'conectada';
  }
  bool get isDobot => (controller ?? '').toLowerCase().contains('dobot');

  factory Machine.fromJson(Map<String, dynamic> json) {
    final alertItems = json['alertas'] as List? ?? const [];
    final logItems = json['logs'] as List? ?? const [];

    return Machine(
      id: _int(json['id']),
      name: '${json['nome'] ?? 'Máquina'}',
      sector: '${json['setor'] ?? '-'}',
      model: '${json['modelo'] ?? '-'}',
      code: '${json['codigo'] ?? '-'}',
      status: '${json['status'] ?? 'Ligada'}',
      temperature: _double(json['temperatura']),
      vibration: _double(json['vibracao']),
      current: _double(json['corrente']),
      production: _int(json['producao']),
      cycles: _int(json['ciclos']),
      energy: _double(json['consumoEnergia']),
      simulation: json['modoSimulacao'] != false,
      connection: _connection(json),
      safetyStop: json['paradaSeguranca'] == true,
      controller: json['controlador']?.toString(),
      protocol: json['protocolo']?.toString(),
      maintenanceStatus: '${json['manutencao'] ?? 'Normal'}',
      lastMaintenance: '${json['ultimaManutencao'] ?? 'Sem registro'}',
      nextMaintenance: '${json['proximaManutencao'] ?? 'A definir'}',
      logs: logItems.map((item) {
        if (item is Map) return '${item['mensagem'] ?? ''}';
        return '$item';
      }).where((item) => item.isNotEmpty).toList(),
      alerts: alertItems
          .whereType<Map>()
          .map((item) => MachineAlert.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      extraData: Map<String, dynamic>.from(
        json['dadosExtrasAtuais'] as Map? ?? const {},
      ),
      manufacturer: json['fabricante']?.toString(),
      type: json['tipo']?.toString(),
      description: json['descricao']?.toString(),
      host: json['host']?.toString(),
      endpoint: json['endpoint']?.toString(),
      topic: json['topico']?.toString(),
      port: json['porta'] == null ? null : _int(json['porta']),
      unitId: json['unitId'] == null ? null : _int(json['unitId']),
      readInterval: _int(json['intervaloLeitura']) == 0 ? 2000 : _int(json['intervaloLeitura']),
      temperatureWarning: _doubleOr(json['tempAtencao'], 55),
      temperatureCritical: _doubleOr(json['tempCritica'], 70),
      energyWarning: _doubleOr(json['energiaAtencao'], 80),
      energyCritical: _doubleOr(json['energiaCritica'], 90),
      vibrationWarning: _doubleOr(json['vibracaoAtencao'], 4),
      vibrationCritical: _doubleOr(json['vibracaoCritica'], 7),
      maintenanceCycles: _int(json['ciclosManutencao']) == 0 ? 1000 : _int(json['ciclosManutencao']),
      integrationMeta: Map<String, dynamic>.from(json['integracaoMeta'] as Map? ?? const {}),
      signalQuality: _optionalDouble(
        json['qualidadeSinal'] ??
            (json['estadoConexao'] is Map ? (json['estadoConexao'] as Map)['qualidadeSinal'] : null),
      ),
      latencyMs: _optionalDouble(
        json['latenciaMs'] ??
            (json['estadoConexao'] is Map ? (json['estadoConexao'] as Map)['latenciaMs'] : null),
      ),
    );
  }
}

class MachineAlert {
  const MachineAlert({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String message;
  final DateTime? createdAt;

  factory MachineAlert.fromJson(Map<String, dynamic> json) => MachineAlert(
        id: _int(json['id']),
        type: '${json['tipo'] ?? 'Alerta'}',
        message: '${json['mensagem'] ?? ''}',
        createdAt: DateTime.tryParse('${json['criadoEm'] ?? ''}'),
      );
}

class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.type,
    required this.technician,
    required this.description,
    required this.date,
    required this.time,
    this.cycles,
  });

  final int id;
  final String type;
  final String technician;
  final String description;
  final String date;
  final String time;
  final int? cycles;

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) => MaintenanceRecord(
        id: _int(json['id']),
        type: '${json['tipo'] ?? '-'}',
        technician: '${json['tecnico'] ?? '-'}',
        description: '${json['descricao'] ?? '-'}',
        date: '${json['data'] ?? '-'}',
        time: '${json['horario'] ?? '-'}',
        cycles: json['ciclosNoRegistro'] == null ? null : _int(json['ciclosNoRegistro']),
      );
}

int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
double? _optionalDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
double _doubleOr(dynamic value, double fallback) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  return parsed ?? fallback;
}

String _connection(Map<String, dynamic> json) {
  final state = json['estadoConexao'];
  if (state is Map) {
    return '${state['codigo'] ?? state['texto'] ?? 'Offline'}';
  }
  return '${state ?? json['statusConexao'] ?? 'Offline'}';
}

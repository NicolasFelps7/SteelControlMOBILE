import 'package:flutter_test/flutter_test.dart';
import 'package:steelcontrol_mobile/models/machine.dart';

void main() {
  test('juntas antigas não substituem telemetria recente; offline e simulação não são pose real', () {
    final now = DateTime.now();
    final m = Machine.fromJson({
      'id': 1,
      'modoSimulacao': false,
      'statusConexao': 'CONECTADA',
      'ultimaTelemetriaEm': now.toIso8601String(),
      'dadosExtrasAtuais': {
        'dobot': {
          'joints': {'j1': 25},
        },
      },
    });
    expect(m.hasRecentTelemetry, isTrue);
    final old = m.mergeRealtime({
      'ultimaTelemetriaEm': now
          .subtract(const Duration(seconds: 10))
          .toIso8601String(),
      'dadosExtras': {
        'dobot': {
          'joints': {'j1': 99},
        },
      },
    });
    expect(old.extraData['dobot']['joints']['j1'], 25);
    expect(
      m.mergeRealtime({'statusConexao': 'OFFLINE'}).hasRecentTelemetry,
      isFalse,
    );
    expect(
      m.mergeRealtime({'modoSimulacao': true}).hasRecentTelemetry,
      isFalse,
    );
  });
}

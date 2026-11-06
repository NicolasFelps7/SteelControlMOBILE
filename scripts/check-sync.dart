import '../lib/state/machine_sync_scope.dart';
import '../lib/core/dobot_command_policy.dart';
import '../lib/models/machine.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final gate = MachineSyncScope();
  final generation = gate.generation;
  final delayed = Future<List<int>>.delayed(Duration.zero, () => [12, 13]);
  gate.remove(12);
  final visible = (await delayed).where((id) => !gate.isRemoved(id)).toList();
  check(
    !visible.contains(12) && visible.contains(13),
    'Snapshot restaurou exclusão',
  );
  gate.reset();
  check(!gate.accepts(generation), 'Resposta de sessão antiga foi aceita');
  check(!gate.isRemoved(12), 'Exclusão vazou entre sessões');
  gate.remove(12);
  check(!gate.isRemoved(14), 'Código reutilizado com novo ID foi bloqueado');
  final valid = {'x': 100, 'y': 0, 'z': 50, 'r': 0, 'velocidade': 60};
  check(
    DobotCommandPolicy.validate('DOBOT_PTP', valid) == null,
    'PTP válido bloqueado',
  );
  for (final value in [61, 0, double.nan, double.infinity]) {
    check(
      DobotCommandPolicy.validate('DOBOT_PTP', {
            ...valid,
            'velocidade': value,
          }) !=
          null,
      'Velocidade inválida foi aceita',
    );
  }
  for (final field in DobotCommandPolicy.bounds.entries) {
    check(
      DobotCommandPolicy.validate('DOBOT_PTP', {
            ...valid,
            field.key: field.value.$2 + 1,
          }) !=
          null,
      'Envelope de posição não foi validado',
    );
  }
  check(
    DobotCommandPolicy.validate('DOBOT_HOME', {}) ==
        'DOBOT_LOCAL_HOME_REQUIRED',
    'HOME remoto aceito',
  );
  check(
    DobotCommandPolicy.validate('SHELL', {}) != null,
    'Comando desconhecido aceito',
  );
  check(
    DobotCommandPolicy.validate('DOBOT_ROTATE', {'delta': 21}) != null,
    'Rotação fora de limite',
  );
  check(
    DobotCommandPolicy.validate('DOBOT_STOP', {}) == null,
    'STOP bloqueado',
  );
  final machine = Machine.fromJson({
    'id': 14,
    'codigo': 'BR-777',
    'modoSimulacao': false,
    'estadoConexao': 'Offline',
    'controlador': 'DOBOT_MAGICIAN',
  });
  check(
    machine.id == 14 && !machine.isOnline && machine.isDobot,
    'Estado real incorreto',
  );
  print(
    'PASSOU: exclusão com resposta atrasada, isolamento de sessão, novo ID, limites e comandos Dobot.',
  );
}

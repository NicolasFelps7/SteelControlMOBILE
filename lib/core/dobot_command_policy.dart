/// Limites conservadores iguais aos da API. A API e o Edge revalidam o comando.
class DobotCommandPolicy {
  static const commands = {
    'DOBOT_STOP',
    'DOBOT_CLEAR_ALARMS',
    'DOBOT_PTP',
    'DOBOT_ROTATE',
    'DOBOT_SUCTION_ON',
    'DOBOT_SUCTION_OFF',
    'DOBOT_GRIPPER_OPEN',
    'DOBOT_GRIPPER_CLOSE',
  };
  static const bounds = <String, (double, double)>{
    'x': (-290, 290),
    'y': (-290, 290),
    'z': (-10, 220),
    'r': (-180, 180),
  };
  static bool _within(dynamic value, double min, double max) =>
      value is num && value.isFinite && value >= min && value <= max;

  static String? validate(String command, Map<String, dynamic> data) {
    if (command == 'DOBOT_HOME') return 'DOBOT_LOCAL_HOME_REQUIRED';
    if (!commands.contains(command)) return 'DOBOT_INVALID_COMMAND';
    if (command == 'DOBOT_PTP') {
      for (final field in bounds.entries) {
        if (!_within(data[field.key], field.value.$1, field.value.$2)) {
          return 'DOBOT_INVALID_PAYLOAD';
        }
      }
    }
    if (command == 'DOBOT_ROTATE' &&
        (!_within(data['delta'], -20, 20) || data['delta'] == 0)) {
      return 'DOBOT_INVALID_PAYLOAD';
    }
    if ((command == 'DOBOT_PTP' || command == 'DOBOT_ROTATE') &&
        !_within(data['velocidade'] ?? 20, 1, 60)) {
      return 'DOBOT_INVALID_PAYLOAD';
    }
    return null;
  }
}

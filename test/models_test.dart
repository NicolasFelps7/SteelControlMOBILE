import 'package:flutter_test/flutter_test.dart';
import 'package:steelcontrol_mobile/models/machine.dart';
import 'package:steelcontrol_mobile/models/session.dart';
import 'package:steelcontrol_mobile/core/app_strings.dart';

void main() {
  group('Modelos sincronizados com o backend', () {
    test('interpreta uma máquina Dobot e seus indicadores', () {
      final machine = Machine.fromJson({
        'id': 7,
        'nome': 'Braço robótico',
        'setor': 'Automação',
        'modelo': 'Magician',
        'codigo': 'DOBOT-01',
        'status': 'Ligada',
        'temperatura': 32.5,
        'vibracao': 0.8,
        'corrente': 1.4,
        'producao': 120,
        'ciclos': 45,
        'consumoEnergia': 55,
        'modoSimulacao': false,
        'estadoConexao': 'Online',
        'controlador': 'Dobot Magician',
      });

      expect(machine.id, 7);
      expect(machine.isDobot, isTrue);
      expect(machine.isOnline, isTrue);
      expect(machine.temperature, 32.5);
      expect(machine.production, 120);
    });

    test('interpreta conexão estruturada e limites do cadastro profissional', () {
      final machine = Machine.fromJson({
        'id': 8,
        'nome': 'Torno CNC',
        'setor': 'Usinagem',
        'modelo': 'TX-20',
        'codigo': 'CNC-08',
        'status': 'Ligada',
        'modoSimulacao': false,
        'estadoConexao': {'codigo': 'OFFLINE', 'texto': 'Offline'},
        'qualidadeSinal': 87,
        'latenciaMs': 24,
        'tempAtencao': 58,
        'tempCritica': 74,
        'energiaAtencao': 75,
        'energiaCritica': 92,
        'ciclosManutencao': 1500,
      });

      expect(machine.isOnline, isFalse);
      expect(machine.temperatureWarning, 58);
      expect(machine.temperatureCritical, 74);
      expect(machine.energyCritical, 92);
      expect(machine.maintenanceCycles, 1500);
      expect(machine.signalQuality, 87);
      expect(machine.latencyMs, 24);
    });

    test('mantém sessão, empresa e usuário do mesmo backend', () {
      final session = Session.fromJson({
        'token': 'token-seguro',
        'usuario': {
          'id': 3,
          'nome': 'Nicolas',
          'email': 'nicolas@empresa.com',
          'cargo': 'Administrador',
        },
        'empresa': {
          'id': 9,
          'nome': 'Empresa TCC',
          'cnpj': '00.000.000/0001-00',
          'logoUrl': '/uploads/logo.png',
        },
      });

      expect(session.token, 'token-seguro');
      expect(session.user.name, 'Nicolas');
      expect(session.company.name, 'Empresa TCC');
      expect(session.company.logoUrl, '/uploads/logo.png');
    });

    test('aceita os nomes de campo de logo usados pelo backend', () {
      final camelCase = Company.fromJson({'id': 1, 'nome': 'A', 'logoUrl': '/a.png'});
      final snakeCase = Company.fromJson({'id': 2, 'nome': 'B', 'logo_url': '/b.png'});
      final legacy = Company.fromJson({'id': 3, 'nome': 'C', 'logo': '/c.png'});

      expect(camelCase.logoUrl, '/a.png');
      expect(snakeCase.logoUrl, '/b.png');
      expect(legacy.logoUrl, '/c.png');
    });
  });

  group('Internacionalização', () {
    test('traduz as áreas críticas da interface nos seis idiomas', () {
      for (final language in AppLanguage.values) {
        final strings = AppStrings(language);
        expect(strings.get('maintenanceCenter'), isNotEmpty);
        expect(strings.get('machineLogs'), isNotEmpty);
        expect(strings.get('preferencesTitle'), isNotEmpty);
        expect(strings.get('editCompany'), isNotEmpty);
        expect(strings.get('confirmLogoutTitle'), isNotEmpty);
      }
      expect(AppStrings(AppLanguage.en).get('maintenanceCenter'), 'Maintenance center');
      expect(AppStrings(AppLanguage.es).get('editCompany'), 'Editar empresa');
    });
  });
}

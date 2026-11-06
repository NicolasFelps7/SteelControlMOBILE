import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:steelcontrol_mobile/core/api_config.dart';
import 'package:steelcontrol_mobile/core/app_strings.dart';
import 'package:steelcontrol_mobile/services/api_client.dart';
import 'package:steelcontrol_mobile/services/machine_service.dart';

import '../scripts/check-sync.dart' as invariants;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('exclusões, troca de sessão e limites do Dobot', invariants.main);

  test('migra URL provisória para o Railway', () async {
    SharedPreferences.setMockInitialValues({
      'steelcontrol_api_url': 'https://127.0.0.1:3000',
    });
    await ApiConfig.load(
      healthClient: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(ApiConfig.baseUrl, 'https://web-production-6682df.up.railway.app');
  });

  test('mantém servidor personalizado mesmo indisponível', () async {
    SharedPreferences.setMockInitialValues({
      'steelcontrol_api_url': 'https://empresa.example',
    });
    await ApiConfig.load(
      healthClient: MockClient((_) async => http.Response('{}', 503)),
    );
    expect(ApiConfig.baseUrl, 'https://empresa.example');
  });

  test('bloqueia URL com credenciais, parâmetros ou HTTP', () {
    for (final url in [
      'https://user:pass@example.com',
      'https://example.com?token=x',
      'https://example.com#x',
      'http://example.com',
      'https://example.com/api',
    ]) {
      expect(() => ApiConfig.normalize(url), throwsFormatException);
    }
  });

  test(
    'cliente mantém token no servidor de origem e não segue redirecionamento',
    () async {
      await ApiConfig.save('https://empresa-a.example');
      final client = ApiClient(
        token: 'token-de-teste',
        transport: MockClient((request) async {
          expect(request.url.host, 'empresa-a.example');
          expect(request.headers['Authorization'], 'Bearer token-de-teste');
          expect(request.followRedirects, isFalse);
          return http.Response('{}', 200);
        }),
      );
      await ApiConfig.save('https://empresa-b.example');
      await client.get('/maquinas');
    },
  );

  test('não repete POST após falha de conexão', () async {
    var attempts = 0;
    final client = ApiClient(
      transport: MockClient((_) async {
        attempts++;
        throw const SocketException('sem rede');
      }),
    );
    await expectLater(
      client.post('/maquinas/12/comandos', body: {'comando': 'DOBOT_STOP'}),
      throwsA(isA<ApiException>()),
    );
    expect(attempts, 1);
  });

  test('normaliza erro de permissão do backend', () async {
    final client = ApiClient(
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({'mensagem': 'Acesso negado', 'codigo': 'FORBIDDEN'}),
          403,
        ),
      ),
    );
    await expectLater(
      client.get('/maquinas/99'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.code, 'code', 'FORBIDDEN'),
      ),
    );
  });

  test('HOME é recusado antes de transmitir ao backend', () async {
    var requests = 0;
    final service = MachineService(
      ApiClient(
        transport: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      ),
    );
    await expectLater(
      service.sendDobotCommand(12, 'DOBOT_HOME'),
      throwsA(isA<ApiException>()),
    );
    expect(requests, 0);
  });

  test('novas mensagens têm tradução nos seis idiomas', () {
    for (final language in AppLanguage.values) {
      final s = AppStrings(language);
      for (final key in [
        'desktopHero',
        'registrationConfirmation',
        'edgeInstructions',
        'edgeSelectPort',
        'edgeKeepOn',
        'localCalibration',
        'dobotInvalidCommand',
      ]) {
        expect(s.get(key), isNotEmpty);
        expect(s.get(key), isNot(key));
      }
    }
  });
}

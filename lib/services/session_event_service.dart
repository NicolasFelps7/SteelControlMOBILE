import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';

class SessionEventService {
  SessionEventService({
    required this.token,
    required this.onRevoked,
  });

  final String token;
  final Future<void> Function(String reason) onRevoked;

  http.Client? _client;
  StreamSubscription<String>? _subscription;
  bool _stopped = false;
  int _generation = 0;

  Future<void> start() async {
    _stopped = false;
    final generation = ++_generation;
    await _connect(generation);
  }

  Future<void> _connect(int generation) async {
    if (_stopped || generation != _generation || token.isEmpty) return;

    await _subscription?.cancel();
    _subscription = null;
    _client?.close();

    final client = http.Client();
    _client = client;

    try {
      final request = http.Request(
        'GET',
        ApiConfig.uri('/auth/session-events'),
      )
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Authorization'] = 'Bearer $token';

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 12));

      if (_stopped || generation != _generation) {
        client.close();
        return;
      }

      if (response.statusCode == 401) {
        await onRevoked('');
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _scheduleReconnect(generation);
        return;
      }

      String? currentEvent;
      String? currentData;
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      _subscription = lines.listen(
        (line) async {
          if (_stopped || generation != _generation) return;

          if (line.startsWith('event:')) {
            currentEvent = line.substring(6).trim();
            return;
          }

          if (line.startsWith('data:')) {
            currentData = line.substring(5).trim();
            return;
          }

          if (line.isEmpty) {
            if (currentEvent == 'revoked') {
              var reason = 'Seu acesso ao SteelControl foi encerrado pelo administrador.';
              try {
                final payload = jsonDecode(currentData ?? '{}');
                if (payload is Map) {
                  final serverReason = '${payload['motivo'] ?? ''}'.trim();
                  if (serverReason.isNotEmpty) reason = serverReason;
                }
              } catch (_) {
                // Mantém a mensagem padrão.
              }
              await onRevoked(reason);
            }
            currentEvent = null;
            currentData = null;
          }
        },
        onError: (_) => _scheduleReconnect(generation),
        onDone: () => _scheduleReconnect(generation),
        cancelOnError: true,
      );
    } on TimeoutException {
      _scheduleReconnect(generation);
    } catch (_) {
      _scheduleReconnect(generation);
    }
  }

  void _scheduleReconnect(int generation) {
    if (_stopped || generation != _generation) return;

    Future<void>.delayed(const Duration(seconds: 3), () {
      if (_stopped || generation != _generation) return;
      _connect(generation);
    });
  }

  Future<void> stop() async {
    _stopped = true;
    _generation += 1;
    await _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }
}

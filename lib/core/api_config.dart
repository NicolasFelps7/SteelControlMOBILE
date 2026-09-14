import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  ApiConfig._();

  static const _storageKey = 'steelcontrol_api_url';
  static const _explicitCompiledUrl = String.fromEnvironment('API_URL');
  static const _emulatorUrl = 'http://10.0.2.2:3000';
  static const _usbReverseUrl = 'http://127.0.0.1:3000';

  static String _baseUrl = _emulatorUrl;

  static String get baseUrl => _baseUrl.replaceAll(RegExp(r'/+$'), '');

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_storageKey)?.trim();
    final explicit = _explicitCompiledUrl.trim();

    if (explicit.isNotEmpty) {
      _baseUrl = _normalize(explicit);
      return;
    }

    final candidates = <String>[
      if (saved?.isNotEmpty == true) _normalize(saved!),
      _emulatorUrl,
      _usbReverseUrl,
    ];

    final seen = <String>{};
    for (final candidate in candidates) {
      if (!seen.add(candidate)) continue;
      if (await _healthCheck(candidate)) {
        _baseUrl = candidate;
        if (candidate != saved) {
          await preferences.setString(_storageKey, candidate);
        }
        return;
      }
    }

    _baseUrl = saved?.isNotEmpty == true ? _normalize(saved!) : _emulatorUrl;
  }

  static Future<void> save(String value) async {
    final normalized = _normalize(value);
    _baseUrl = normalized;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, normalized);
  }

  static Future<bool> _healthCheck(String base) async {
    try {
      final response = await http
          .get(Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}/api/health'))
          .timeout(const Duration(milliseconds: 1400));
      return response.statusCode >= 200 && response.statusCode < 300;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static String _normalize(String value) {
    var normalized = value.trim();
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(normalized)) {
      normalized = 'http://$normalized';
    }
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null ||
        !uri.hasScheme ||
        (scheme != 'http' && scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('Informe um endereço HTTP válido.');
    }
    return normalized;
  }

  static Uri uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleanPath').replace(
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }
}

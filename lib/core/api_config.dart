import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  ApiConfig._();

  static const _storageKey = 'steelcontrol_api_url';
  static const _compiledDefault = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static String _baseUrl = _compiledDefault;

  static String get baseUrl => _baseUrl.replaceAll(RegExp(r'/+$'), '');

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _baseUrl = preferences.getString(_storageKey) ?? _compiledDefault;
  }

  static Future<void> save(String value) async {
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

    _baseUrl = normalized;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, normalized);
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


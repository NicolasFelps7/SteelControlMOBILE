import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/app_strings.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.token, this.language = AppLanguage.pt});

  String? token;
  final AppLanguage language;
  String _text(String key) => AppStrings(language).get(key);

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token?.isNotEmpty == true) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _send(() => http.get(ApiConfig.uri(path, query), headers: _headers));
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _send(() => http.post(
          ApiConfig.uri(path),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _send(() => http.put(
          ApiConfig.uri(path),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> delete(String path) async {
    return _send(() => http.delete(ApiConfig.uri(path), headers: _headers));
  }

  Future<dynamic> multipart(
    String path, {
    required Map<String, File> files,
  }) async {
    try {
      final request = http.MultipartRequest('POST', ApiConfig.uri(path));
      request.headers['Accept'] = 'application/json';
      if (token?.isNotEmpty == true) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      for (final entry in files.entries) {
        request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value.path));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 35));
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } on SocketException {
      throw ApiException(_text('networkUnavailable'));
    } on TimeoutException {
      throw ApiException(_text('requestTimeout'));
    }
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    try {
      return _decode(await request().timeout(const Duration(seconds: 20)));
    } on SocketException {
      throw ApiException(_text('networkUnavailable'));
    } on HttpException {
      throw ApiException(_text('connectionInterrupted'));
    } on TimeoutException {
      throw ApiException(_text('requestTimeout'));
    }
  }

  dynamic _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      throw ApiException(_text('invalidServerResponse'), statusCode: response.statusCode);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? '${decoded['mensagem'] ?? decoded['message'] ?? _text('operationFailed')}'
          : _text('operationFailed');
      throw ApiException(message, statusCode: response.statusCode);
    }

    return decoded;
  }
}

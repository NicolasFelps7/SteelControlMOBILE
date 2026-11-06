import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/api_config.dart';
import '../core/app_strings.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code, this.data});

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? data;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    this.token,
    this.language = AppLanguage.pt,
    http.Client? transport,
  }) : baseUrl = ApiConfig.baseUrl,
       _transport = transport;

  final String baseUrl;
  final http.Client? _transport;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    if (path.contains('://') || path.startsWith('//')) {
      throw const FormatException('Use um caminho relativo da API.');
    }
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleanPath').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final client = _transport ?? http.Client();
    try {
      final request = http.Request(method, _uri(path, query))
        ..followRedirects = false
        ..headers.addAll(_headers);
      if (body != null) request.body = jsonEncode(body);
      return await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
    } finally {
      if (_transport == null) client.close();
    }
  }

  String? token;
  final AppLanguage language;
  String _text(String key) => AppStrings(language).get(key);

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-SteelControl-Client': 'mobile',
    if (token?.isNotEmpty == true) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _request('GET', path, query: query), retries: 1);

  // Escritas e comandos nunca são repetidos automaticamente pelo app.
  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _request('POST', path, body: body));
  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _request('PUT', path, body: body));
  Future<dynamic> delete(String path) => _send(() => _request('DELETE', path));

  Stream<Map<String, dynamic>> sse(String path) async* {
    final client = http.Client();

    try {
      final request = http.Request('GET', _uri(path))..followRedirects = false;
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['X-SteelControl-Client'] = 'mobile';
      if (token?.isNotEmpty == true) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        dynamic decoded;
        try {
          decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
        } catch (_) {
          decoded = <String, dynamic>{};
        }
        final message = decoded is Map
            ? '${decoded['mensagem'] ?? decoded['message'] ?? _text('operationFailed')}'
            : _text('operationFailed');
        throw ApiException(
          message,
          statusCode: response.statusCode,
          code: decoded is Map
              ? '${decoded['codigo'] ?? decoded['code'] ?? ''}'.trim()
              : null,
          data: decoded is Map ? Map<String, dynamic>.from(decoded) : null,
        );
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            yield Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
    } on SocketException {
      throw ApiException(_text('networkUnavailable'));
    } on TimeoutException {
      throw ApiException(_text('requestTimeout'));
    } finally {
      client.close();
    }
  }

  Future<dynamic> multipart(
    String path, {
    required Map<String, File> files,
    Map<String, String> fields = const <String, String>{},
    bool binaryFiles = false,
  }) async {
    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST', _uri(path))
        ..followRedirects = false;
      request.headers['Accept'] = 'application/json';
      request.headers['X-SteelControl-Client'] = 'mobile';
      if (token?.isNotEmpty == true) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields.addAll(fields);

      for (final entry in files.entries) {
        final mediaType = binaryFiles
            ? MediaType('application', 'pkcs7-signature')
            : await _detectImageMediaType(entry.value);
        request.files.add(
          await http.MultipartFile.fromPath(
            entry.key,
            entry.value.path,
            contentType: mediaType,
          ),
        );
      }

      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 35));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 35));
      return _decode(response);
    } on SocketException {
      throw ApiException(_text('networkUnavailable'));
    } on TimeoutException {
      throw ApiException(_text('requestTimeout'));
    } finally {
      client.close();
    }
  }

  Future<MediaType> _detectImageMediaType(File file) async {
    final handle = await file.open();
    try {
      final bytes = await handle.read(40);
      if (bytes.length >= 3 &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xD8 &&
          bytes[2] == 0xFF) {
        return MediaType('image', 'jpeg');
      }
      if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0D &&
          bytes[5] == 0x0A &&
          bytes[6] == 0x1A &&
          bytes[7] == 0x0A) {
        return MediaType('image', 'png');
      }
      if (bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        return MediaType('image', 'webp');
      }
      if (bytes.length >= 6) {
        final header = String.fromCharCodes(bytes.sublist(0, 6));
        if (header == 'GIF87a' || header == 'GIF89a') {
          return MediaType('image', 'gif');
        }
      }
      if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
        return MediaType('image', 'bmp');
      }
      if (bytes.length >= 16 &&
          String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp') {
        final brands = String.fromCharCodes(bytes.sublist(8));
        if (brands.contains('avif') || brands.contains('avis')) {
          return MediaType('image', 'avif');
        }
      }
    } finally {
      await handle.close();
    }

    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'jpg' || extension == 'jpeg')
      return MediaType('image', 'jpeg');
    if (extension == 'png') return MediaType('image', 'png');
    if (extension == 'webp') return MediaType('image', 'webp');
    if (extension == 'gif') return MediaType('image', 'gif');
    if (extension == 'avif') return MediaType('image', 'avif');
    if (extension == 'bmp') return MediaType('image', 'bmp');
    throw ApiException(_text('invalidImageFormat'));
  }

  Future<dynamic> _send(
    Future<http.Response> Function() request, {
    int retries = 0,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return _decode(await request().timeout(const Duration(seconds: 20)));
      } on SocketException {
        if (attempt++ < retries) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
        throw ApiException(_text('networkUnavailable'));
      } on HttpException {
        if (attempt++ < retries) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
        throw ApiException(_text('connectionInterrupted'));
      } on TimeoutException {
        if (attempt++ < retries) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
        throw ApiException(_text('requestTimeout'));
      }
    }
  }

  dynamic _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        _text('invalidServerResponse'),
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? '${decoded['mensagem'] ?? decoded['message'] ?? _text('operationFailed')}'
          : _text('operationFailed');
      throw ApiException(
        message,
        statusCode: response.statusCode,
        code: decoded is Map
            ? '${decoded['codigo'] ?? decoded['code'] ?? ''}'.trim()
            : null,
        data: decoded is Map ? Map<String, dynamic>.from(decoded) : null,
      );
    }

    return decoded;
  }
}

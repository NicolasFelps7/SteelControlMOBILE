import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

class SessionStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _key = 'steelcontrol_session';

  Future<void> save(Map<String, dynamic> json) async {
    await _storage.write(key: _key, value: jsonEncode(json));
  }

  Future<Session?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;

    try {
      return Session.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _key);
}


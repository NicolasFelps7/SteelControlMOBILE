import 'dart:io';

import '../models/session.dart';
import 'api_client.dart';

class CompanyService {
  CompanyService(this.client);

  final ApiClient client;

  Stream<Map<String, dynamic>> events() => client.sse('/empresa/stream');

  Future<Company> getCompany() async {
    final result = await client.get('/empresa/me');
    return Company.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<List<Map<String, dynamic>>> users() async {
    final result = await client.get('/empresa/usuarios') as List;
    return result.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<List<Map<String, dynamic>>> audit({int limit = 100}) async {
    final safeLimit = limit.clamp(1, 300);
    final result = await client.get('/auditoria', query: {'limit': safeLimit});
    final items = result is List
        ? result
        : result is Map
            ? (result['itens'] as List? ??
                result['auditoria'] as List? ??
                result['logs'] as List? ??
                const [])
            : const [];
    return items.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<Company> uploadLogo(File image) async {
    await client.multipart(
      '/empresa/logo',
      files: {'logo': image},
    );
    return getCompany();
  }

  Future<Company> removeLogo() async {
    await client.delete('/empresa/logo');
    return getCompany();
  }

  Future<Company> updateCompany({
    required String name,
    required String cnpj,
    String? email,
    String? phone,
    String? address,
    String? number,
    String? district,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? website,
  }) async {
    final result = await client.put('/empresa/me', body: {
      'nome': name.trim(),
      'cnpj': cnpj.trim(),
      'email': email?.trim(),
      'telefone': phone?.trim(),
      'endereco': address?.trim(),
      'numero': number?.trim(),
      'bairro': district?.trim(),
      'cidade': city?.trim(),
      'estado': state?.trim(),
      'cep': zipCode?.trim(),
      'pais': country?.trim(),
      'site': website?.trim(),
    });
    final data = Map<String, dynamic>.from(result as Map);
    return Company.fromJson(Map<String, dynamic>.from(data['empresa'] as Map? ?? data));
  }

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async => Map<String, dynamic>.from(await client.post('/empresa/usuarios', body: {
        'nome': name.trim(),
        'email': email.trim(),
        'senha': password,
        'cargo': role,
      }) as Map);

  Future<Map<String, dynamic>> updateUser(
    int userId, {
    required String name,
    required String email,
    required String role,
    String? password,
  }) async => Map<String, dynamic>.from(await client.put('/empresa/usuarios/$userId', body: {
        'nome': name.trim(),
        'email': email.trim(),
        'cargo': role,
        if (password?.isNotEmpty == true) 'senha': password,
      }) as Map);

  Future<void> dismissUser(int userId) => client.delete('/empresa/usuarios/$userId');

  Future<List<Map<String, dynamic>>> faces(int userId) async {
    final result = await client.get('/empresa/usuarios/$userId/faces');
    final items = result is List ? result : (result is Map ? (result['faciais'] as List? ?? result['faces'] as List? ?? const []) : const []);
    return items.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> registerUserFace(
    int userId, {
    required File initialImage,
    required File finalImage,
    required File livenessImage,
    String? faceName,
  }) async {
    await client.multipart(
      '/empresa/usuarios/$userId/face-image',
      files: {
        'imagem': finalImage,
        'inicial': initialImage,
        'liveness': livenessImage,
      },
      fields: {
        if (faceName?.trim().isNotEmpty == true) 'nomeFacial': faceName!.trim(),
      },
    );
  }

  Future<void> removeFace(int userId, int faceId) =>
      client.delete('/empresa/usuarios/$userId/faces/$faceId');

  Future<void> removeAllFaces(int userId) => client.delete('/empresa/usuarios/$userId/face');

  Future<void> requestEmailChange(int userId, String email) => client.post(
        '/empresa/usuarios/$userId/email-verification/request',
        body: {'email': email.trim()},
      );

  Future<void> confirmEmailChange(int userId, String email, String code) => client.post(
        '/empresa/usuarios/$userId/email-verification/confirm',
        body: {'email': email.trim(), 'codigo': code.trim()},
      );
}

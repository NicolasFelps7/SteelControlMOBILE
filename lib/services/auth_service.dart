import 'dart:io';

import '../models/session.dart';
import 'api_client.dart';

class AuthService {
  AuthService(this.client);

  final ApiClient client;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await client.post(
      '/auth/login',
      body: {'email': email.trim(), 'senha': password},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> faceLogin({
    required File finalImage,
    required File livenessImage,
  }) async {
    final result = await client.multipart(
      '/auth/face/login-image',
      files: {'imagem': finalImage, 'liveness': livenessImage},
    );
    return Map<String, dynamic>.from(result as Map);
  }


  Future<Map<String, dynamic>> requestFaceSecondFactor({
    required String challengeId,
    required String email,
  }) async {
    final result = await client.post(
      '/auth/face/ambiguous/request-code',
      body: {
        'challengeId': challengeId,
        'email': email.trim().toLowerCase(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> verifyFaceSecondFactor({
    required String challengeId,
    required String email,
    required String code,
  }) async {
    final result = await client.post(
      '/auth/face/ambiguous/verify-code',
      body: {
        'challengeId': challengeId,
        'email': email.trim().toLowerCase(),
        'codigo': code.replaceAll(RegExp(r'\D'), '').trim(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> analyzeFace(File image) async {
    final result = await client.multipart(
      '/auth/face/analyze-image',
      files: {'imagem': image},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> requestRegistrationCode({
    required String companyName,
    required String cnpj,
    required String adminName,
    required String email,
    required String password,
  }) async {
    final result = await client.post(
      '/auth/register-company/request-code',
      body: {
        'empresa': {'nome': companyName.trim(), 'cnpj': cnpj.trim()},
        'administrador': {
          'nome': adminName.trim(),
          'email': email.trim(),
          'senha': password,
        },
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> confirmRegistrationCode(
    String verificationId,
    String code,
  ) async {
    final result = await client.post(
      '/auth/register-company/confirm-code',
      body: {'verificacaoId': verificationId, 'codigo': code},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> completeRegistrationFace({
    required String verificationId,
    required File initialImage,
    required File finalImage,
    required File livenessImage,
  }) async {
    final result = await client.multipart(
      '/auth/register-company/complete-face',
      files: {
        'imagem': finalImage,
        'inicial': initialImage,
        'liveness': livenessImage,
      },
      fields: {'verificacaoId': verificationId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  // Mantido para compatibilidade com fluxos autenticados antigos.
  Future<void> registerFace(File image, String token) async {
    final authenticated = ApiClient(token: token, language: client.language);
    await authenticated.multipart(
      '/auth/face/register-image',
      files: {'imagem': image},
    );
  }

  Session parseSession(Map<String, dynamic> json) => Session.fromJson(json);
}

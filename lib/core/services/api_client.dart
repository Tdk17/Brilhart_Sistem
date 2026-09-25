import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  static const serverUrl = String.fromEnvironment(
    'PARSE_SERVER_URL',
    defaultValue: 'https://parseapi.back4app.com',
  );
  static const applicationId = String.fromEnvironment('PARSE_APPLICATION_ID');
  static const restApiKey = String.fromEnvironment('PARSE_REST_API_KEY');
  static const clientKey = String.fromEnvironment('PARSE_CLIENT_KEY');

  String? sessionToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Parse-Application-Id': applicationId,
        if (restApiKey.isNotEmpty)
          'X-Parse-REST-API-Key': restApiKey
        else if (clientKey.isNotEmpty)
          'X-Parse-Client-Key': clientKey,
        if (sessionToken != null && sessionToken!.isNotEmpty)
          'X-Parse-Session-Token': sessionToken!,
      };

  void _ensureConfigured() {
    if (applicationId.isEmpty) {
      throw const ApiException(
        'PARSE_APPLICATION_ID não configurado no build.',
      );
    }
    if (restApiKey.isEmpty && clientKey.isEmpty) {
      throw const ApiException(
        'Chave do Back4App não configurada no build.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      final body = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
      final preview = body.length > 220 ? '${body.substring(0, 220)}…' : body;
      throw ApiException(
        'Resposta inválida do servidor (${response.statusCode}). $preview',
        statusCode: response.statusCode,
      );
    }
  }

  ApiException _responseError(
    http.Response response,
    Map<String, dynamic> decoded,
  ) {
    final code = decoded['code'];
    final message = decoded['error']?.toString() ??
        decoded['message']?.toString() ??
        'Erro ${response.statusCode}';
    return ApiException(
      code == null ? message : '$message (código $code)',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    _ensureConfigured();
    final response = await http
        .post(
          Uri.parse('$serverUrl/login'),
          headers: _headers,
          body: jsonEncode({
            'username': username.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseError(response, decoded);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> me() async {
    _ensureConfigured();
    if (sessionToken == null || sessionToken!.isEmpty) {
      throw const ApiException('Sessão não encontrada.');
    }

    final response = await http
        .get(
          Uri.parse('$serverUrl/users/me'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));

    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseError(response, decoded);
    }
    return decoded;
  }

  Future<void> logout() async {
    _ensureConfigured();
    if (sessionToken == null || sessionToken!.isEmpty) return;

    final response = await http
        .post(
          Uri.parse('$serverUrl/logout'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = _decode(response);
      throw _responseError(response, decoded);
    }
  }

  Future<Map<String, dynamic>> cloud(
    String function, [
    Map<String, dynamic> payload = const {},
  ]) async {
    _ensureConfigured();

    final response = await http
        .post(
          Uri.parse('$serverUrl/functions/$function'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    final decoded = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _responseError(response, decoded);
    }

    final result = decoded['result'];
    if (result is Map<String, dynamic>) return result;
    return {'data': result};
  }
}

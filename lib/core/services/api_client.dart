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
  static const clientKey = String.fromEnvironment('PARSE_CLIENT_KEY');

  String? sessionToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Parse-Application-Id': applicationId,
        if (clientKey.isNotEmpty) 'X-Parse-Client-Key': clientKey,
        if (sessionToken != null && sessionToken!.isNotEmpty)
          'X-Parse-Session-Token': sessionToken!,
      };

  Future<Map<String, dynamic>> cloud(
    String function,
    [Map<String, dynamic> payload = const {}],
  ) async {
    if (applicationId.isEmpty) {
      throw const ApiException(
        'PARSE_APPLICATION_ID não configurado no build.',
      );
    }

    final response = await http
        .post(
          Uri.parse('$serverUrl/functions/$function'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['error']?.toString() ?? 'Erro ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final result = decoded['result'];
    if (result is Map<String, dynamic>) return result;
    return {'data': result};
  }
}

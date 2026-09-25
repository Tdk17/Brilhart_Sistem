import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

import 'api_client.dart';

class AuthService {
  AuthService(this._api);

  final ApiClient _api;
  final isAuthenticated = signal(false);
  final isLoading = signal(false);
  final userName = signal<String?>(null);

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('sessionToken');
    if (token == null || token.isEmpty) return;

    _api.sessionToken = token;
    try {
      final me = await _api.cloud('v1-auth-me');
      userName.value = me['name']?.toString() ?? me['username']?.toString();
      isAuthenticated.value = true;
    } catch (_) {
      await logout(localOnly: true);
    }
  }

  Future<void> login(String email, String password) async {
    isLoading.value = true;
    try {
      final result = await _api.cloud('v1-auth-login', {
        'email': email.trim(),
        'password': password,
      });
      final token = result['sessionToken']?.toString();
      if (token == null || token.isEmpty) {
        throw const ApiException('Sessão não retornada pelo backend.');
      }
      _api.sessionToken = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sessionToken', token);
      userName.value = result['name']?.toString() ?? result['username']?.toString();
      isAuthenticated.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout({bool localOnly = false}) async {
    if (!localOnly) {
      try {
        await _api.cloud('v1-auth-logout');
      } catch (_) {}
    }
    _api.sessionToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionToken');
    userName.value = null;
    isAuthenticated.value = false;
  }
}

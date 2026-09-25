import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'app.dart';
import 'core/services/api_client.dart';
import 'core/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();
  final auth = AuthService(api);
  await auth.restoreSession();

  GetIt.I
    ..registerSingleton<ApiClient>(api)
    ..registerSingleton<AuthService>(auth);

  runApp(const BrilhartApp());
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:brilhart_sistem/core/services/api_client.dart';
import 'package:brilhart_sistem/core/services/auth_service.dart';
import 'package:brilhart_sistem/core/theme/app_theme.dart';
import 'package:brilhart_sistem/features/fiscal/fiscal_page.dart';
import 'package:brilhart_sistem/features/shell/app_shell.dart';

class _TestApi extends ApiClient {
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> cloud(String function, [Map<String, dynamic> payload = const {}]) async {
    calls.add(function);
    if (function == 'v1-company-settings-get') return {};
    if (function == 'v1-fiscal-config-get') return {
      'ready': false, 'environment': 'homologacao', 'profiles': [],
      'missing': ['Dados fiscais da empresa', 'Credencial do emissor'],
    };
    if (function == 'v1-fiscal-invoices-list') return {'items': [], 'hasMore': false};
    throw StateError('Unexpected fiscal operation: $function');
  }
}

void main() {
  late _TestApi api;
  setUp(() {
    api = _TestApi();
    GetIt.I.registerSingleton<ApiClient>(api);
    GetIt.I.registerSingleton<AuthService>(AuthService(api));
  });
  tearDown(() async { await GetIt.I.reset(); });

  for (final width in [1440.0, 390.0]) {
    testWidgets('fiscal workspace at $width: pending setup cannot emit and has no overflow', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final router = GoRouter(initialLocation: '/notas-fiscais', routes: [
        ShellRoute(builder: (_, __, child) => AppShell(child: child), routes: [
          GoRoute(path: '/notas-fiscais', builder: (_, __) => const FiscalPage()),
        ]),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Emitir NFS-e'));
      expect(button.onPressed, isNull);
      expect(find.textContaining('Configuração fiscal pendente'), findsOneWidget);
      expect(api.calls.where((c) => c.contains('-issue')), isEmpty);
      if (Platform.environment['CI'] == 'true') {
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('build/ui-previews')..createSync(recursive: true);
          File('${directory.path}/fiscal-${width.toInt()}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}

import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_page.dart';
import '../../features/public/quote_request_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/shared/module_page.dart';
import '../services/auth_service.dart';

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  redirect: (context, state) {
    final auth = GetIt.I<AuthService>();
    final logged = auth.isAuthenticated.value;
    final publicRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/solicitar-orcamento';

    if (!logged && !publicRoute) return '/login';
    if (logged && state.matchedLocation == '/login') return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(
      path: '/solicitar-orcamento',
      builder: (_, __) => const QuoteRequestPage(),
    ),
    ShellRoute(
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
        GoRoute(
          path: '/clientes',
          builder: (_, __) => const ModulePage(
            title: 'Clientes',
            subtitle: 'Cadastro, busca, ficha completa e histórico do cliente.',
            listFunction: 'v1-clients-list',
            icon: 'clientes',
          ),
        ),
        GoRoute(
          path: '/solicitacoes',
          builder: (_, __) => const ModulePage(
            title: 'Novas Solicitações',
            subtitle: 'Solicitações de orçamento vindas do site, com fotos e origem preservada.',
            listFunction: 'v1-quote-requests-list',
            icon: 'solicitacoes',
          ),
        ),
        GoRoute(
          path: '/orcamentos',
          builder: (_, __) => const ModulePage(
            title: 'Orçamentos',
            subtitle: 'Orçamentos oficiais, PDF A4, status e conversão em serviço.',
            listFunction: 'v1-quotes-list',
            icon: 'orcamentos',
          ),
        ),
        GoRoute(
          path: '/producao',
          builder: (_, __) => const ModulePage(
            title: 'Produção',
            subtitle: 'Serviços em produção, prazos, atrasos, conclusão e histórico.',
            listFunction: 'v1-services-list',
            icon: 'producao',
          ),
        ),
        GoRoute(
          path: '/faturamento',
          builder: (_, __) => const ModulePage(
            title: 'Faturamento',
            subtitle: 'Receita por período, serviço e origem sem contabilização duplicada.',
            listFunction: 'v1-billing-summary',
            icon: 'faturamento',
          ),
        ),
        GoRoute(
          path: '/contratos',
          builder: (_, __) => const ModulePage(
            title: 'Contratos',
            subtitle: 'Contratos vinculados a clientes e serviços, com PDF e status.',
            listFunction: 'v1-contracts-list',
            icon: 'contratos',
          ),
        ),
        GoRoute(
          path: '/documentos',
          builder: (_, __) => const ModulePage(
            title: 'Central de Documentos',
            subtitle: 'Orçamentos, contratos, notas e anexos organizados por cliente.',
            listFunction: 'v1-documents-list',
            icon: 'documentos',
          ),
        ),
        GoRoute(
          path: '/configuracoes',
          builder: (_, __) => const ModulePage(
            title: 'Configurações',
            subtitle: 'Dados da empresa, logo, Pix, WhatsApp e padrões dos documentos.',
            listFunction: 'v1-company-settings-get',
            icon: 'configuracoes',
          ),
        ),
      ],
    ),
  ],
);

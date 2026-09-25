import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_page.dart';
import '../../features/billing/billing_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/public/quote_request_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/shared/module_page.dart';
import '../../features/shell/app_shell.dart';
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
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardPage(),
        ),
        GoRoute(
          path: '/clientes',
          builder: (_, __) => const ModulePage(
            title: 'Clientes',
            subtitle:
                'Cadastro, busca, ficha completa e histórico de solicitações, orçamentos, serviços e documentos.',
            listFunction: 'v1-clients-list',
            createFunction: 'v1-clients-create',
            updateFunction: 'v1-clients-update',
            deleteFunction: 'v1-clients-delete',
            icon: 'clientes',
            fields: [
              ModuleField(key: 'name', label: 'Nome', required: true),
              ModuleField(
                  key: 'phone',
                  label: 'Telefone / WhatsApp',
                  type: ModuleFieldType.phone,
                  required: true),
              ModuleField(
                  key: 'cityAddress',
                  label: 'Endereço / cidade',
                  required: true),
            ],
            actions: [
              ModuleAction.whatsapp(),
            ],
          ),
        ),
        GoRoute(
          path: '/solicitacoes',
          builder: (_, __) => const ModulePage(
            title: 'Novas Solicitações',
            subtitle:
                'Solicitações de orçamento vindas do site, com fotos, origem, atendimento e conversão.',
            listFunction: 'v1-quote-requests-list',
            icon: 'solicitacoes',
            allowCreate: false,
            originBadge: true,
            actions: [
              ModuleAction.whatsapp(),
              ModuleAction.cloud(
                label: 'Marcar em atendimento',
                function: 'v1-quote-requests-set-status',
                icon: Icons.mark_email_read_outlined,
                payload: {'status': 'Em atendimento'},
              ),
              ModuleAction.cloud(
                label: 'Converter em cliente',
                function: 'v1-quote-requests-convert-client',
                icon: Icons.person_add_alt_1_outlined,
                confirmMessage:
                    'O sistema verificará o telefone para evitar cliente duplicado. Continuar?',
              ),
              ModuleAction.cloud(
                label: 'Converter em orçamento',
                function: 'v1-quote-requests-convert-quote',
                icon: Icons.request_quote_outlined,
                confirmMessage:
                    'Criar orçamento oficial reutilizando os dados desta solicitação?',
              ),
            ],
          ),
        ),
        GoRoute(
          path: '/orcamentos',
          builder: (_, __) => const ModulePage(
            title: 'Orçamentos',
            subtitle:
                'Orçamentos oficiais com dados do cliente, status, valor, prazo, PDF A4 e conversão em serviço.',
            listFunction: 'v1-quotes-list',
            createFunction: 'v1-quotes-create',
            updateFunction: 'v1-quotes-update',
            icon: 'orcamentos',
            originBadge: true,
            fields: [
              ModuleField(
                  key: 'clientId', label: 'Cliente (ID)', required: true),
              ModuleField(key: 'status', label: 'Status', required: true),
              ModuleField(key: 'baseColor', label: 'Cor base'),
              ModuleField(
                  key: 'serviceType',
                  label: 'Tipo de serviço',
                  required: true),
              ModuleField(
                  key: 'description',
                  label: 'Descrição',
                  type: ModuleFieldType.multiline,
                  required: true),
              ModuleField(
                  key: 'value',
                  label: 'Valor',
                  type: ModuleFieldType.money,
                  required: true),
              ModuleField(
                  key: 'paymentMethod',
                  label: 'Forma de pagamento',
                  required: true),
              ModuleField(
                  key: 'dueDate',
                  label: 'Prazo de entrega',
                  type: ModuleFieldType.date),
              ModuleField(key: 'measurements', label: 'Metragem'),
              ModuleField(
                  key: 'additionalMeasurements',
                  label: 'Metragem adicional'),
              ModuleField(key: 'origin', label: 'Origem'),
            ],
            actions: [
              ModuleAction.cloud(
                label: 'Gerar / visualizar PDF',
                function: 'v1-quotes-pdf',
                icon: Icons.picture_as_pdf_outlined,
                openReturnedUrl: true,
              ),
              ModuleAction.cloud(
                label: 'Converter em serviço',
                function: 'v1-quotes-convert-service',
                icon: Icons.precision_manufacturing_outlined,
                confirmMessage:
                    'O orçamento deve estar aprovado. Criar serviço sem redigitar os dados?',
              ),
              ModuleAction.whatsapp(label: 'Contato do cliente'),
            ],
          ),
        ),
        GoRoute(
          path: '/producao',
          builder: (_, __) => const ModulePage(
            title: 'Produção',
            subtitle:
                'Serviços, prazos, atrasos, conclusão e histórico de alterações.',
            listFunction: 'v1-services-list',
            createFunction: 'v1-services-create',
            updateFunction: 'v1-services-update',
            icon: 'producao',
            fields: [
              ModuleField(
                  key: 'clientId', label: 'Cliente (ID)', required: true),
              ModuleField(
                  key: 'description',
                  label: 'Descrição',
                  type: ModuleFieldType.multiline,
                  required: true),
              ModuleField(
                  key: 'serviceType',
                  label: 'Tipo de serviço',
                  required: true),
              ModuleField(key: 'measurements', label: 'Metragem'),
              ModuleField(
                  key: 'value',
                  label: 'Valor',
                  type: ModuleFieldType.money),
              ModuleField(
                  key: 'dueDate',
                  label: 'Prazo',
                  type: ModuleFieldType.date,
                  required: true),
              ModuleField(key: 'status', label: 'Status', required: true),
            ],
            actions: [
              ModuleAction.cloud(
                label: 'Marcar como concluído',
                function: 'v1-services-complete',
                icon: Icons.task_alt_outlined,
                confirmMessage:
                    'Confirmar conclusão? A data de conclusão será registrada pelo backend.',
              ),
            ],
          ),
        ),
        GoRoute(
          path: '/faturamento',
          builder: (_, __) => const BillingPage(),
        ),
        GoRoute(
          path: '/contratos',
          builder: (_, __) => const ModulePage(
            title: 'Contratos',
            subtitle:
                'Contratos vinculados a clientes e serviços/orçamentos, com PDF, upload assinado e histórico.',
            listFunction: 'v1-contracts-list',
            createFunction: 'v1-contracts-create',
            updateFunction: 'v1-contracts-update',
            icon: 'contratos',
            fields: [
              ModuleField(
                  key: 'clientId', label: 'Cliente (ID)', required: true),
              ModuleField(key: 'serviceId', label: 'Serviço (ID)'),
              ModuleField(key: 'quoteId', label: 'Orçamento (ID)'),
              ModuleField(key: 'status', label: 'Status', required: true),
              ModuleField(
                  key: 'signedFile',
                  label: 'Contrato assinado',
                  type: ModuleFieldType.file),
            ],
            actions: [
              ModuleAction.cloud(
                label: 'Gerar / visualizar PDF',
                function: 'v1-contracts-pdf',
                icon: Icons.picture_as_pdf_outlined,
                openReturnedUrl: true,
              ),
              ModuleAction.whatsapp(label: 'Contato do cliente'),
            ],
          ),
        ),
        GoRoute(
          path: '/documentos',
          builder: (_, __) => const ModulePage(
            title: 'Central de Documentos',
            subtitle:
                'Orçamentos, contratos, notas/documentos de fechamento e anexos organizados por cliente.',
            listFunction: 'v1-documents-list',
            createFunction: 'v1-documents-create',
            updateFunction: 'v1-documents-update',
            icon: 'documentos',
            fields: [
              ModuleField(
                  key: 'clientId', label: 'Cliente (ID)', required: true),
              ModuleField(key: 'serviceId', label: 'Serviço (ID)'),
              ModuleField(
                  key: 'type', label: 'Tipo de documento', required: true),
              ModuleField(key: 'number', label: 'Número'),
              ModuleField(
                  key: 'date',
                  label: 'Data',
                  type: ModuleFieldType.date),
              ModuleField(
                  key: 'value',
                  label: 'Valor',
                  type: ModuleFieldType.money),
              ModuleField(
                  key: 'note',
                  label: 'Observação',
                  type: ModuleFieldType.multiline),
              ModuleField(
                  key: 'file',
                  label: 'Selecionar arquivo',
                  type: ModuleFieldType.file,
                  required: true),
            ],
            actions: [
              ModuleAction.cloud(
                label: 'Visualizar / baixar',
                function: 'v1-documents-download',
                icon: Icons.picture_as_pdf_outlined,
                openReturnedUrl: true,
              ),
              ModuleAction.whatsapp(label: 'Contato do cliente'),
            ],
          ),
        ),
        GoRoute(
          path: '/configuracoes',
          builder: (_, __) => const SettingsPage(),
        ),
      ],
    ),
  ],
);

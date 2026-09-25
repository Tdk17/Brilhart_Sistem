import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _items = <_NavItem>[
    _NavItem('/dashboard', 'Dashboard', Icons.dashboard_outlined),
    _NavItem('/clientes', 'Clientes', Icons.people_outline),
    _NavItem('/solicitacoes', 'Solicitações', Icons.notifications_active_outlined),
    _NavItem('/orcamentos', 'Orçamentos', Icons.request_quote_outlined),
    _NavItem('/producao', 'Produção', Icons.precision_manufacturing_outlined),
    _NavItem('/faturamento', 'Faturamento', Icons.payments_outlined),
    _NavItem('/contratos', 'Contratos', Icons.description_outlined),
    _NavItem('/documentos', 'Documentos', Icons.folder_copy_outlined),
    _NavItem('/configuracoes', 'Configurações', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;

    if (compact) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.black,
          title: Row(
            children: [
              Image.asset(
                'assets/images/brilhart_logo.png',
                height: 34,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.format_paint,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 10),
              const Text('BrilhArte Sistem'),
            ],
          ),
        ),
        drawer: Drawer(
          backgroundColor: AppColors.surface,
          child: SafeArea(child: _Menu(items: _items)),
        ),
        body: child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 270,
            child: ColoredBox(
              color: AppColors.surface,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                      child: Image.asset(
                        'assets/images/brilhart_logo.png',
                        height: 86,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.format_paint,
                          size: 56,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _Menu(items: _items)),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.items});

  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, index) {
              final item = items[index];
              final selected = location == item.path;
              return ListTile(
                selected: selected,
                selectedColor: AppColors.black,
                selectedTileColor: AppColors.gold,
                iconColor: selected ? AppColors.black : AppColors.silver,
                textColor: selected ? AppColors.black : AppColors.silver,
                leading: Icon(item.icon),
                title: Text(
                  item.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.maybePop(context);
                  context.go(item.path);
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: ListTile(
            leading: const Icon(Icons.logout, color: AppColors.silver),
            title: const Text('Sair'),
            onTap: () async {
              await GetIt.I<AuthService>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

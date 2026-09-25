import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brilhart_logo.dart';

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
          titleSpacing: 12,
          title: const Row(
            children: [
              BrilhartLogo(height: 34, width: 110),
              SizedBox(width: 10),
              Text('Brilhart Sistem', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        drawer: Drawer(
          backgroundColor: AppColors.surface,
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 22, 18, 16),
                  child: BrilhartLogo(height: 86),
                ),
                const Divider(height: 1),
                Expanded(child: _Menu(items: _items)),
              ],
            ),
          ),
        ),
        body: child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 286,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 18),
                      child: BrilhartLogo(height: 92),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'GESTÃO OPERACIONAL',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.silverDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    Expanded(child: _Menu(items: _items)),
                  ],
                ),
              ),
            ),
          ),
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
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, index) {
              final item = items[index];
              final selected = location == item.path;
              return ListTile(
                minTileHeight: 50,
                selected: selected,
                selectedColor: AppColors.gold,
                selectedTileColor: const Color(0xFF211C0D),
                iconColor: selected ? AppColors.gold : AppColors.silver,
                textColor: selected ? AppColors.gold : AppColors.silver,
                leading: Icon(item.icon, size: 21),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected
                        ? AppColors.gold.withValues(alpha: .55)
                        : Colors.transparent,
                  ),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

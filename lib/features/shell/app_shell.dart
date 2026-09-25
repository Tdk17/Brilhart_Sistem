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
          backgroundColor: AppColors.surface,
          titleSpacing: 8,
          title: const _BrandHeader(compact: true),
        ),
        drawer: Drawer(
          backgroundColor: AppColors.surface,
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: _BrandHeader(),
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
          Container(
            width: 248,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                right: BorderSide(color: Colors.white10),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 20, 18, 16),
                    child: _BrandHeader(),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _Menu(items: _items)),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 42 : 52,
          height: compact ? 42 : 52,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: .35)),
          ),
          child: Image.asset(
            'assets/images/brilhart_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.format_paint_outlined,
              color: AppColors.gold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                compact ? 'Brilhart' : 'Brilhart Sistem',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 17 : 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 3),
                const Text(
                  'GESTÃO OPERACIONAL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.silverDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 5),
            itemBuilder: (_, index) {
              final item = items[index];
              final selected = location == item.path;

              return Material(
                color: selected ? AppColors.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  minTileHeight: 46,
                  dense: true,
                  horizontalTitleGap: 11,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                  leading: Icon(
                    item.icon,
                    size: 20,
                    color: selected ? AppColors.black : AppColors.silver,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? AppColors.black : AppColors.silver,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.black,
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.maybePop(context);
                    context.go(item.path);
                  },
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ListTile(
            minTileHeight: 46,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(
              Icons.logout_rounded,
              size: 20,
              color: AppColors.silver,
            ),
            title: const Text(
              'Sair',
              style: TextStyle(
                color: AppColors.silver,
                fontWeight: FontWeight.w600,
              ),
            ),
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

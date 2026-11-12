import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_client.dart';
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
    _NavItem('/notas-fiscais', 'Notas fiscais', Icons.receipt_long_outlined),
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
          backgroundColor: AppColors.sidebar,
          titleSpacing: 8,
          title: const _BrandHeader(compact: true),
        ),
        drawer: Drawer(
          backgroundColor: AppColors.sidebar,
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
          Material(
            color: AppColors.sidebar,
            child: Container(
              width: 246,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: _BrandHeader(),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _Menu(items: _items)),
                ],
              ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [const _WorkspaceBar(), Expanded(child: child)],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceBar extends StatelessWidget {
  const _WorkspaceBar();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final title = AppShell._items
        .where((item) => item.path == location)
        .map((item) => item.label)
        .firstOrNull ?? 'Gestão';
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(child: Text(title,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        Tooltip(
          message: 'Central fiscal',
          child: IconButton(
            onPressed: () => context.go('/notas-fiscais'),
            icon: const Icon(Icons.receipt_long_outlined,
              size: 20, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 12),
        const CircleAvatar(
          radius: 16, backgroundColor: AppColors.surfaceAlt,
          child: Icon(Icons.person_outline, size: 18, color: AppColors.textMuted),
        ),
      ]),
    );
  }
}

class _BrandHeader extends StatefulWidget {
  const _BrandHeader({this.compact = false});

  final bool compact;

  @override
  State<_BrandHeader> createState() => _BrandHeaderState();
}

class _BrandHeaderState extends State<_BrandHeader> {
  String? _logoUrl;
  String _tradeName = 'Brilhart';

  @override
  void initState() {
    super.initState();
    _loadCompanyBrand();
  }

  Future<void> _loadCompanyBrand() async {
    try {
      final result = await GetIt.I<ApiClient>().cloud('v1-company-settings-get');
      if (!mounted) return;
      setState(() {
        final logoUrl = '${result['logoUrl'] ?? ''}'.trim();
        final tradeName = '${result['tradeName'] ?? ''}'.trim();
        _logoUrl = logoUrl.isEmpty ? null : logoUrl;
        if (tradeName.isNotEmpty) _tradeName = tradeName;
      });
    } catch (_) {
      // A identidade visual nunca deve impedir o carregamento do sistema.
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = widget.compact ? 38.0 : 42.0;

    return Row(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.sidebar,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _logoUrl != null
                ? Image.network(
                    _logoUrl!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => _fallbackLogo(),
                  )
                : _fallbackLogo(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.compact ? _tradeName : 'Brilhart Sistem',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.compact ? 16 : 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
              if (!widget.compact) ...[
                const SizedBox(height: 3),
                const Text(
                  'GESTÃO OPERACIONAL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallbackLogo() {
    return Image.asset(
      'assets/images/brilhart_logo.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const Center(
        child: Text(
          'B',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
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
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 22),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (_, index) {
              final item = items[index];
              final selected = location == item.path;

              return Material(
                color: selected ? AppColors.surfaceAlt : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: ListTile(
                  minTileHeight: 44,
                  dense: true,
                  horizontalTitleGap: 11,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                  leading: Icon(
                    item.icon,
                    size: 20,
                    color: selected ? AppColors.primarySoft : AppColors.textMuted,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? AppColors.white : AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
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
              color: AppColors.textSecondary,
            ),
            title: const Text(
              'Sair',
              style: TextStyle(
                color: AppColors.textSecondary,
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

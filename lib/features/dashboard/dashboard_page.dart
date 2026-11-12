import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await GetIt.I<ApiClient>().cloud('v1-dashboard-metrics');
      if (mounted) setState(() => _data = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _number(String key) => int.tryParse('${_data?[key] ?? 0}') ?? 0;
  double _amount(String key) => double.tryParse('${_data?[key] ?? 0}') ?? 0;
  String get _revenue => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(_amount('revenue'));

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(compact ? 18 : 32, compact ? 24 : 32, compact ? 18 : 32, 48),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Visão geral', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('Acompanhe a operação em um só lugar.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              ]),
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Atualizar'),
              ),
            ],
          ),
          const SizedBox(height: 30),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _MinimalPanel(
              title: 'Não foi possível carregar os indicadores',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Verifique sua conexão com o servidor e tente novamente.',
                  style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: _load, child: const Text('Tentar novamente')),
              ]),
            )
          else ...[
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1020 ? 4 : constraints.maxWidth >= 520 ? 2 : 1;
              final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
              return Wrap(spacing: 14, runSpacing: 14, children: [
                SizedBox(width: width, child: _Stat(
                  label: 'Em produção', value: '${_number('inProduction')}',
                  icon: Icons.precision_manufacturing_outlined)),
                SizedBox(width: width, child: _Stat(
                  label: 'Atrasados', value: '${_number('lateServices')}',
                  icon: Icons.schedule_outlined,
                  warning: _number('lateServices') > 0)),
                SizedBox(width: width, child: _Stat(
                  label: 'Concluídos', value: '${_number('completedServices')}',
                  icon: Icons.check_circle_outline)),
                SizedBox(width: width, child: _Stat(
                  label: 'Faturamento', value: _revenue,
                  icon: Icons.account_balance_wallet_outlined)),
              ]);
            }),
            const SizedBox(height: 30),
            LayoutBuilder(builder: (context, constraints) {
              final priorities = _priorities();
              final upcoming = _upcoming();
              if (constraints.maxWidth >= 920) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 4, child: priorities),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: upcoming),
                ]);
              }
              return Column(children: [priorities, const SizedBox(height: 16), upcoming]);
            }),
          ],
        ],
      ),
    );
  }

  Widget _priorities() => _MinimalPanel(
    title: 'Pendências',
    subtitle: 'O que precisa da sua atenção',
    child: Column(children: [
      _DetailRow(
        icon: Icons.schedule_outlined,
        title: 'Serviços atrasados',
        description: 'Entregas fora do prazo',
        value: '${_number('lateServices')}',
        warning: _number('lateServices') > 0,
      ),
      const Divider(height: 26),
      _DetailRow(
        icon: Icons.mail_outline,
        title: 'Novas solicitações',
        description: 'Orçamentos recebidos pelo site',
        value: '${_number('newQuoteRequests')}',
      ),
    ]),
  );

  Widget _upcoming() {
    final raw = _data?['upcomingServices'];
    final rows = raw is List ? raw : const [];
    return _MinimalPanel(
      title: 'Próximas entregas',
      subtitle: 'Serviços com prazo previsto',
      child: rows.isEmpty
        ? const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: Text('Nenhuma entrega próxima.',
            style: TextStyle(color: AppColors.textMuted))),
        )
        : Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            Builder(builder: (_) {
              final item = rows[i] is Map
                ? Map<String, dynamic>.from(rows[i] as Map)
                : <String, dynamic>{};
              return _DeliveryRow(
                client: '${item['clientName'] ?? 'Cliente'}',
                description: '${item['description'] ?? 'Serviço'}',
                date: '${item['dueDate'] ?? '-'}',
              );
            }),
            if (i < rows.length - 1) const Divider(height: 24),
          ],
        ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon, this.warning = false});
  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    height: 142,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 19, color: warning ? AppColors.warning : AppColors.textMuted),
        const SizedBox(width: 9),
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
      ]),
      const Spacer(),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.5)),
    ]),
  );
}

class _MinimalPanel extends StatelessWidget {
  const _MinimalPanel({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      if (subtitle != null) ...[
        const SizedBox(height: 5),
        Text(subtitle!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
      const SizedBox(height: 25),
      child,
    ]),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.title,
    required this.description, required this.value, this.warning = false});
  final IconData icon;
  final String title;
  final String description;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 20, color: AppColors.textMuted),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(description, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ])),
    const SizedBox(width: 10),
    Text(value, style: TextStyle(
      color: warning ? AppColors.warning : AppColors.white,
      fontWeight: FontWeight.w700, fontSize: 18)),
  ]);
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.client, required this.description, required this.date});
  final String client;
  final String description;
  final String date;

  @override
  Widget build(BuildContext context) => Row(children: [
    const Icon(Icons.event_outlined, size: 20, color: AppColors.textMuted),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(client, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(description, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ])),
    const SizedBox(width: 8),
    Text(date, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
  ]);
}

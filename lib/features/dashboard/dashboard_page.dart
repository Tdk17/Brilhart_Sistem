import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? data;
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await GetIt.I<ApiClient>().cloud('v1-dashboard-metrics');
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int _int(String key) => int.tryParse('${data?[key] ?? 0}') ?? 0;
  double _double(String key) => double.tryParse('${data?[key] ?? 0}') ?? 0;

  String _money(double value) {
    final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $fixed';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 32),
        children: [
          _header(),
          const SizedBox(height: 22),
          if (loading)
            const _LoadingDashboard()
          else if (error != null)
            _ErrorCard(error: error!, onRetry: _load)
          else ...[
            _overviewBanner(),
            const SizedBox(height: 18),
            _metricsGrid(),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 980) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _attentionPanel()),
                      const SizedBox(width: 18),
                      Expanded(flex: 6, child: _upcomingPanel()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _attentionPanel(),
                    const SizedBox(height: 18),
                    _upcomingPanel(),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Central de Operações',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Dashboard',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5),
              Text(
                'Visão consolidada da operação, produção e desempenho comercial da Brilhart.',
                style: TextStyle(color: AppColors.silverDark),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Tooltip(
          message: 'Atualizar dados',
          child: IconButton.filledTonal(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }

  Widget _overviewBanner() {
    final late = _int('lateServices');
    final requests = _int('newQuoteRequests');
    final upcoming = (data?['upcomingServices'] as List?)?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF17140C), Color(0xFF0F0F0F)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: .24)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final status = late > 0
              ? '$late serviço(s) requerem atenção'
              : 'Operação sem atrasos registrados';

          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.monitor_heart_outlined,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Resumo operacional',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Indicadores atualizados diretamente pelo backend de produção.',
                style: TextStyle(color: AppColors.silverDark),
              ),
            ],
          );

          final stats = Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _MiniStat(
                icon: Icons.mark_email_unread_outlined,
                value: '$requests',
                label: 'Novas solicitações',
              ),
              _MiniStat(
                icon: Icons.event_available_outlined,
                value: '$upcoming',
                label: 'Próximas entregas',
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 18),
                stats,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 20),
              stats,
            ],
          );
        },
      ),
    );
  }

  Widget _metricsGrid() {
    final cards = [
      _MetricCard(
        label: 'Em produção',
        value: '${_int('inProduction')}',
        icon: Icons.precision_manufacturing_outlined,
        caption: 'Serviços atualmente em execução',
      ),
      _MetricCard(
        label: 'Atrasados',
        value: '${_int('lateServices')}',
        icon: Icons.warning_amber_rounded,
        caption: 'Serviços fora do prazo',
        danger: _int('lateServices') > 0,
      ),
      _MetricCard(
        label: 'Concluídos',
        value: '${_int('completedServices')}',
        icon: Icons.verified_outlined,
        caption: 'Serviços finalizados',
      ),
      _MetricCard(
        label: 'Faturamento',
        value: _money(_double('revenue')),
        icon: Icons.account_balance_wallet_outlined,
        caption: 'Receita consolidada no sistema',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1180 ? 4 : width >= 680 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 3.4 : 2.25,
          children: cards,
        );
      },
    );
  }

  Widget _attentionPanel() {
    final late = _int('lateServices');
    final requests = _int('newQuoteRequests');

    return _SectionCard(
      title: 'Atenção operacional',
      subtitle: 'Prioridades que merecem acompanhamento',
      icon: Icons.notifications_active_outlined,
      child: Column(
        children: [
          _AttentionRow(
            icon: Icons.warning_amber_rounded,
            title: 'Serviços atrasados',
            subtitle: late > 0
                ? 'Existem $late serviço(s) acima do prazo previsto.'
                : 'Nenhum serviço atrasado no momento.',
            value: '$late',
            danger: late > 0,
          ),
          const Divider(height: 26),
          _AttentionRow(
            icon: Icons.mark_email_unread_outlined,
            title: 'Solicitações do site',
            subtitle: requests > 0
                ? '$requests solicitação(ões) aguardando atendimento.'
                : 'Nenhuma nova solicitação aguardando atendimento.',
            value: '$requests',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .025),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .06)),
            ),
            child: const Row(
              children: [
                Icon(Icons.sync_rounded, color: AppColors.gold, size: 18),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Os indicadores são recalculados a cada atualização do dashboard.',
                    style: TextStyle(
                      color: AppColors.silverDark,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _upcomingPanel() {
    final raw = data?['upcomingServices'];
    final services = raw is List ? raw : const [];

    return _SectionCard(
      title: 'Próximos serviços',
      subtitle: 'Agenda organizada por data de entrega',
      icon: Icons.calendar_month_outlined,
      child: services.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 34,
                      color: AppColors.silverDark,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Nenhum serviço próximo.',
                      style: TextStyle(color: AppColors.silverDark),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < services.length; i++) ...[
                  _ServiceRow(item: services[i]),
                  if (i != services.length - 1) const Divider(height: 22),
                ],
              ],
            ),
    );
  }
}

class _LoadingDashboard extends StatelessWidget {
  const _LoadingDashboard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(52),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'Carregando indicadores...',
              style: TextStyle(color: AppColors.silverDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.caption,
    this.danger = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String caption;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.danger : AppColors.gold;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: accent.withValues(alpha: .7), width: 2),
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: accent, size: 21),
                ),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.silverDark,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.silverDark,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.gold, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.silverDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.danger : AppColors.gold;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.silverDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final map = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final client = '${map['clientName'] ?? 'Cliente'}';
    final description = '${map['description'] ?? ''}';
    final dueDate = '${map['dueDate'] ?? '-'}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withValues(alpha: .06)),
          ),
          child: const Icon(
            Icons.handyman_outlined,
            color: AppColors.gold,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(client, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                description.isEmpty ? 'Serviço sem descrição' : description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.silverDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_outlined, color: AppColors.gold, size: 14),
              const SizedBox(width: 5),
              Text(
                dueDate,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 30,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Não foi possível carregar os dados.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.silverDark),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

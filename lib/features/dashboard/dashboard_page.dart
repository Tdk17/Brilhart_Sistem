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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('Visão operacional e comercial da BrilhArte.', style: TextStyle(color: AppColors.silverDark)),
                  ],
                ),
              ),
              IconButton.filledTonal(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 24),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else if (error != null)
            _ErrorCard(error: error!, onRetry: _load)
          else ...[
            LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 1100 ? 4 : width >= 650 ? 2 : 1;
              final cards = [
                _MetricCard('Em produção', '${_int('inProduction')}', Icons.precision_manufacturing_outlined),
                _MetricCard('Atrasados', '${_int('lateServices')}', Icons.warning_amber_rounded, danger: true),
                _MetricCard('Concluídos', '${_int('completedServices')}', Icons.task_alt),
                _MetricCard('Faturamento', 'R\$ ${_double('revenue').toStringAsFixed(2).replaceAll('.', ',')}', Icons.payments_outlined),
              ];
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 2.25,
                children: cards,
              );
            }),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.notifications_active_outlined, color: AppColors.gold),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Novas solicitações do site', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${_int('newQuoteRequests')} aguardando atendimento', style: const TextStyle(color: AppColors.silverDark)),
                        ],
                      ),
                    ),
                    CircleAvatar(backgroundColor: AppColors.gold, foregroundColor: AppColors.black, child: Text('${_int('newQuoteRequests')}')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Próximos serviços por data de entrega', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    if ((data?['upcomingServices'] as List?)?.isEmpty ?? true)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Nenhum serviço próximo.', style: TextStyle(color: AppColors.silverDark))),
                      )
                    else
                      ...((data?['upcomingServices'] as List).cast<Map>()).map((item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(child: Icon(Icons.handyman_outlined)),
                            title: Text('${item['clientName'] ?? 'Cliente'}'),
                            subtitle: Text('${item['description'] ?? ''}'),
                            trailing: Text('${item['dueDate'] ?? ''}', style: const TextStyle(color: AppColors.gold)),
                          )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon, {this.danger = false});
  final String label;
  final String value;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 30, color: danger ? AppColors.danger : AppColors.gold),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: AppColors.silverDark)),
            ])),
          ],
        ),
      ),
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
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: AppColors.gold),
          const SizedBox(height: 12),
          const Text('Não foi possível carregar os dados.'),
          const SizedBox(height: 6),
          Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.silverDark)),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  DateTime? from;
  DateTime? to;
  bool loading = true;
  Object? error;
  Map<String, dynamic> data = const {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    from = DateTime(now.year, now.month, 1);
    to = now;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await GetIt.I<ApiClient>().cloud('v1-billing-summary', {
        if (from != null) 'from': _dateFormat.format(from!),
        if (to != null) 'to': _dateFormat.format(to!),
      });
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String money(dynamic value) {
    final parsed = double.tryParse('$value') ?? 0;
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(parsed);
  }

  Future<void> _pick(bool isFrom) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: isFrom ? (from ?? DateTime.now()) : (to ?? DateTime.now()),
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        from = selected;
      } else {
        to = selected;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final origins = data['origins'];
    final originRows = origins is List ? origins : const [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Faturamento',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Receita por período, serviço e origem, sem contabilização duplicada.',
            style: TextStyle(color: AppColors.silverDark),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text('De: ${from == null ? '-' : DateFormat('dd/MM/yyyy').format(from!)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.event_outlined),
                    label: Text('Até: ${to == null ? '-' : DateFormat('dd/MM/yyyy').format(to!)}'),
                  ),
                  IconButton.filledTonal(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Atualizar',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_outlined, color: AppColors.gold, size: 42),
                    const SizedBox(height: 10),
                    Text('$error', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100
                    ? 4
                    : constraints.maxWidth >= 650
                        ? 2
                        : 1;
                final cards = [
                  _Metric('Faturamento total', money(data['revenue']), Icons.payments_outlined),
                  _Metric('Receita do site', money(data['siteRevenue']), Icons.public_outlined),
                  _Metric('Orçamentos aprovados', '${data['approvedQuotes'] ?? 0}', Icons.task_alt_outlined),
                  _Metric('Solicitações convertidas', '${data['convertedRequests'] ?? 0}', Icons.swap_horiz_outlined),
                ];
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 2.3,
                  children: cards,
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Métricas por origem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    if (originRows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('Sem dados por origem no período.', style: TextStyle(color: AppColors.silverDark)),
                      )
                    else
                      ...originRows.map((raw) {
                        final item = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(child: Icon(Icons.source_outlined)),
                          title: Text('${item['origin'] ?? 'Origem'}'),
                          subtitle: Text('${item['count'] ?? 0} serviço(s)'),
                          trailing: Text(money(item['revenue']), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                        );
                      }),
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

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 30, color: AppColors.gold),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                  Text(label, style: const TextStyle(color: AppColors.silverDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

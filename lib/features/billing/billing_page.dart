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
    setState(() => isFrom ? from = selected : to = selected);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final origins = data['origins'];
    final originRows = origins is List ? origins : const [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 40),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.gold.withValues(alpha: .32)),
                ),
                child: const Icon(Icons.payments_outlined, color: AppColors.gold),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Faturamento', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text(
                      'Visão financeira consolidada por período e origem.',
                      style: TextStyle(color: AppColors.silverDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pick(true),
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text('De ${from == null ? '-' : DateFormat('dd/MM/yyyy').format(from!)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pick(false),
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Até ${to == null ? '-' : DateFormat('dd/MM/yyyy').format(to!)}'),
                ),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (loading)
            _stateCard(const CircularProgressIndicator(), 'Carregando dados financeiros...')
          else if (error != null)
            _errorCard()
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100 ? 4 : constraints.maxWidth >= 650 ? 2 : 1;
                final cards = [
                  _Metric('Faturamento total', money(data['revenue']), Icons.account_balance_wallet_outlined, 'Receita consolidada'),
                  _Metric('Receita do site', money(data['siteRevenue']), Icons.public_outlined, 'Origem digital'),
                  _Metric('Orçamentos aprovados', '${data['approvedQuotes'] ?? 0}', Icons.task_alt_outlined, 'Conversão comercial'),
                  _Metric('Solicitações convertidas', '${data['convertedRequests'] ?? 0}', Icons.swap_horiz_outlined, 'Entrada do site'),
                ];
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 2.15,
                  children: cards,
                );
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pie_chart_outline, color: AppColors.gold),
                      SizedBox(width: 10),
                      Text('Receita por origem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Distribuição comercial do período selecionado.', style: TextStyle(color: AppColors.silverDark)),
                  const SizedBox(height: 18),
                  if (originRows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: Text('Sem dados por origem no período.', style: TextStyle(color: AppColors.silverDark))),
                    )
                  else
                    ...originRows.map((raw) {
                      final item = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF2A2412),
                              child: Icon(Icons.source_outlined, color: AppColors.gold),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item['origin'] ?? 'Origem'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text('${item['count'] ?? 0} serviço(s)', style: const TextStyle(color: AppColors.silverDark, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(money(item['revenue']), style: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w800, fontSize: 15)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stateCard(Widget icon, String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 64),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [icon, const SizedBox(height: 14), Text(text, style: const TextStyle(color: AppColors.silverDark))]),
      );

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.danger, size: 42),
            const SizedBox(height: 10),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.caption);

  final String label;
  final String value;
  final IconData icon;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(caption, style: const TextStyle(color: AppColors.silverDark, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';

class ModulePage extends StatefulWidget {
  const ModulePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.listFunction,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String listFunction;
  final String icon;

  @override
  State<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> {
  final _search = TextEditingController();
  List<dynamic> items = const [];
  bool loading = true;
  Object? error;

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
      final result = await GetIt.I<ApiClient>().cloud(widget.listFunction, {
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
      });
      final raw = result['items'] ?? result['data'] ?? result['results'] ?? const [];
      if (mounted) {
        setState(() => items = raw is List ? raw : [raw]);
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(widget.subtitle, style: const TextStyle(color: AppColors.silverDark)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Novo'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _load(),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nome, telefone, número ou descrição',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(onPressed: _load, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
        else if (error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, color: AppColors.gold, size: 42),
                  const SizedBox(height: 10),
                  Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.silverDark)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
                ],
              ),
            ),
          )
        else if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: Text('Nenhum registro encontrado.', style: TextStyle(color: AppColors.silverDark))),
            ),
          )
        else
          ...items.map((raw) {
            final item = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{'value': raw};
            final title = item['name'] ?? item['clientName'] ?? item['number'] ?? item['title'] ?? 'Registro';
            final status = item['status']?.toString();
            final subtitle = item['phone'] ?? item['description'] ?? item['serviceType'] ?? item['value'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2A2412),
                    child: Icon(Icons.folder_open_outlined, color: AppColors.gold),
                  ),
                  title: Text('$title', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('$subtitle'),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (status != null && status.isNotEmpty)
                        Chip(label: Text(status)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _showDetails(context, item),
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: item.entries
                  .where((entry) => !entry.key.startsWith('_'))
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key, style: const TextStyle(fontSize: 12, color: AppColors.silverDark)),
                            const SizedBox(height: 2),
                            Text('${entry.value}'),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Novo - ${widget.title}'),
        content: const SizedBox(
          width: 520,
          child: Text(
            'A criação deste módulo utiliza a função de gravação correspondente definida no contrato de API. O formulário específico será apresentado conforme os campos do módulo.',
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      ),
    );
  }
}

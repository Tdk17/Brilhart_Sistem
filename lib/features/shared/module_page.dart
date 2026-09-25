import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/services/api_client.dart';
import '../../core/services/external_links.dart';
import '../../core/theme/app_theme.dart';

enum ModuleFieldType { text, multiline, phone, number, money, date, file }

class ModuleField {
  const ModuleField({
    required this.key,
    required this.label,
    this.type = ModuleFieldType.text,
    this.required = false,
  });

  final String key;
  final String label;
  final ModuleFieldType type;
  final bool required;
}

enum ModuleActionType { cloud, whatsapp }

class ModuleAction {
  const ModuleAction.cloud({
    required this.label,
    required this.function,
    this.icon = Icons.play_arrow_outlined,
    this.payload = const {},
    this.confirmMessage,
    this.openReturnedUrl = false,
  }) : type = ModuleActionType.cloud;

  const ModuleAction.whatsapp({
    this.label = 'Chamar no WhatsApp',
    this.icon = Icons.chat_outlined,
  })  : type = ModuleActionType.whatsapp,
        function = null,
        payload = const {},
        confirmMessage = null,
        openReturnedUrl = false;

  final String label;
  final IconData icon;
  final ModuleActionType type;
  final String? function;
  final Map<String, dynamic> payload;
  final String? confirmMessage;
  final bool openReturnedUrl;
}

class ModulePage extends StatefulWidget {
  const ModulePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.listFunction,
    required this.icon,
    this.createFunction,
    this.updateFunction,
    this.deleteFunction,
    this.fields = const [],
    this.actions = const [],
    this.originBadge = false,
    this.allowCreate = true,
  });

  final String title;
  final String subtitle;
  final String listFunction;
  final String icon;
  final String? createFunction;
  final String? updateFunction;
  final String? deleteFunction;
  final List<ModuleField> fields;
  final List<ModuleAction> actions;
  final bool originBadge;
  final bool allowCreate;

  @override
  State<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> {
  final _search = TextEditingController();
  String _status = '';
  List<dynamic> items = const [];
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await GetIt.I<ApiClient>().cloud(widget.listFunction, {
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        if (_status.isNotEmpty) 'status': _status,
      });
      final raw = result['items'] ?? result['data'] ?? result['results'] ?? const [];
      if (mounted) setState(() => items = raw is List ? raw : [raw]);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _idOf(Map<String, dynamic> item) => '${item['objectId'] ?? item['id'] ?? ''}';

  IconData get _moduleIcon {
    switch (widget.icon) {
      case 'clientes':
        return Icons.people_alt_outlined;
      case 'solicitacoes':
        return Icons.notifications_active_outlined;
      case 'orcamentos':
        return Icons.request_quote_outlined;
      case 'producao':
        return Icons.precision_manufacturing_outlined;
      case 'contratos':
        return Icons.description_outlined;
      case 'documentos':
        return Icons.folder_copy_outlined;
      default:
        return Icons.dashboard_customize_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 40),
        children: [
          _pageHeader(),
          const SizedBox(height: 22),
          _summaryStrip(),
          const SizedBox(height: 18),
          _filters(),
          const SizedBox(height: 18),
          if (loading)
            _loadingState()
          else if (error != null)
            _errorCard()
          else if (items.isEmpty)
            _emptyState()
          else
            ...items.map((raw) {
              final item = raw is Map
                  ? Map<String, dynamic>.from(raw)
                  : <String, dynamic>{'value': raw};
              return _recordCard(item);
            }),
        ],
      ),
    );
  }

  Widget _pageHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Row(
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
              child: Icon(_moduleIcon, color: AppColors.gold, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.4),
                  ),
                  const SizedBox(height: 6),
                  Text(widget.subtitle, style: const TextStyle(color: AppColors.silverDark, height: 1.4)),
                ],
              ),
            ),
          ],
        );

        final action = widget.allowCreate && widget.createFunction != null
            ? FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add),
                label: const Text('Novo registro'),
              )
            : null;

        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              if (action != null) ...[
                const SizedBox(height: 16),
                action,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            if (action != null) ...[
              const SizedBox(width: 20),
              action,
            ],
          ],
        );
      },
    );
  }

  Widget _summaryStrip() {
    final visibleCount = items.length;
    final withStatus = items.where((raw) {
      if (raw is! Map) return false;
      final status = raw['status']?.toString() ?? '';
      return status.isNotEmpty;
    }).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _summaryItem(Icons.inventory_2_outlined, '$visibleCount', 'registros exibidos'),
          _summaryItem(Icons.flag_outlined, '$withStatus', 'com status'),
          _summaryItem(Icons.sync_outlined, loading ? 'Atualizando' : 'Sincronizado', 'Back4App'),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.gold),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.silverDark, fontSize: 12)),
      ],
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: _search,
            onSubmitted: (_) => _load(),
            decoration: const InputDecoration(
              hintText: 'Buscar por nome, telefone, número ou descrição',
              prefixIcon: Icon(Icons.search),
            ),
          );
          final status = DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              prefixIcon: Icon(Icons.filter_alt_outlined),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('Todos os status')),
              DropdownMenuItem(value: 'Novo', child: Text('Novo')),
              DropdownMenuItem(value: 'Em atendimento', child: Text('Em atendimento')),
              DropdownMenuItem(value: 'Aguardando cliente', child: Text('Aguardando cliente')),
              DropdownMenuItem(value: 'Aguardando', child: Text('Aguardando')),
              DropdownMenuItem(value: 'Em Produção', child: Text('Em Produção')),
              DropdownMenuItem(value: 'Concluído', child: Text('Concluído')),
              DropdownMenuItem(value: 'Cancelado', child: Text('Cancelado')),
            ],
            onChanged: (value) {
              setState(() => _status = value ?? '');
              _load();
            },
          );
          final refresh = SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
          );

          if (constraints.maxWidth < 780) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                status,
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: refresh),
              ],
            );
          }
          return Row(children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: status),
            const SizedBox(width: 10),
            refresh,
          ]);
        },
      ),
    );
  }

  Widget _loadingState() => Container(
        padding: const EdgeInsets.symmetric(vertical: 72),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Carregando informações...', style: TextStyle(color: AppColors.silverDark)),
          ],
        ),
      );

  Widget _emptyState() => Container(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(_moduleIcon, color: AppColors.gold, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('Nenhum registro encontrado', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 6),
            const Text(
              'Altere os filtros ou adicione um novo registro para começar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.silverDark),
            ),
          ],
        ),
      );

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
        ),
        child: Column(children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.danger, size: 42),
          const SizedBox(height: 12),
          const Text('Não foi possível carregar os dados.', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.silverDark)),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
        ]),
      );

  Widget _recordCard(Map<String, dynamic> item) {
    final title = item['name'] ?? item['clientName'] ?? item['number'] ?? item['title'] ?? item['serviceType'] ?? 'Registro';
    final status = item['status']?.toString();
    final origin = item['origin']?.toString();
    final subtitle = item['phone'] ?? item['description'] ?? item['cityAddress'] ?? item['value'] ?? '';
    final value = item['value'];
    final dueDate = item['dueDate'] ?? item['date'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetails(item),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  if ('$subtitle'.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      '$subtitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.silverDark, height: 1.35),
                    ),
                  ],
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (widget.originBadge && origin != null && origin.isNotEmpty)
                        _softBadge(Icons.source_outlined, 'Origem: $origin', AppColors.silver),
                      if (status != null && status.isNotEmpty)
                        _softBadge(Icons.circle, status, _statusColor(status)),
                      if (value != null && '$value'.isNotEmpty)
                        _softBadge(Icons.payments_outlined, 'R\$ $value', AppColors.goldSoft),
                      if (dueDate != null && '$dueDate'.isNotEmpty)
                        _softBadge(Icons.event_outlined, '$dueDate', AppColors.silver),
                    ],
                  ),
                ],
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_moduleIcon, color: AppColors.gold, size: 23),
                  ),
                  const SizedBox(width: 15),
                  Expanded(child: details),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, color: AppColors.gold),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _softBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value.contains('conclu') || value.contains('aprov') || value.contains('assinado')) return AppColors.success;
    if (value.contains('cancel') || value.contains('atras')) return AppColors.danger;
    if (value.contains('produção') || value.contains('atendimento')) return AppColors.gold;
    return AppColors.silver;
  }

  Future<void> _showDetails(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_moduleIcon, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 16,
                    children: item.entries
                        .where((entry) => !entry.key.startsWith('_') && !entry.key.toLowerCase().contains('base64'))
                        .map((entry) => SizedBox(
                              width: 210,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_fieldLabel(entry.key), style: const TextStyle(fontSize: 11, color: AppColors.silverDark, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  SelectableText('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                if (widget.actions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Ações rápidas', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in widget.actions)
                        OutlinedButton.icon(
                          onPressed: () => _runAction(action, item),
                          icon: Icon(action.icon),
                          label: Text(action.label),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (widget.updateFunction != null && widget.fields.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showForm(item: item);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
          if (widget.deleteFunction != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _delete(item);
              },
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              label: const Text('Excluir', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar')),
        ],
      ),
    );
  }

  String _fieldLabel(String key) {
    const labels = {
      'objectId': 'ID',
      'clientId': 'Cliente',
      'clientName': 'Cliente',
      'clientPhone': 'Telefone',
      'name': 'Nome',
      'phone': 'Telefone / WhatsApp',
      'cityAddress': 'Endereço / cidade',
      'serviceType': 'Tipo de serviço',
      'description': 'Descrição',
      'value': 'Valor',
      'paymentMethod': 'Forma de pagamento',
      'dueDate': 'Prazo / data',
      'measurements': 'Metragem',
      'additionalMeasurements': 'Metragem adicional',
      'baseColor': 'Cor base',
      'status': 'Status',
      'origin': 'Origem',
      'number': 'Número',
      'type': 'Tipo',
      'date': 'Data',
      'note': 'Observação',
      'createdAt': 'Criado em',
      'updatedAt': 'Atualizado em',
    };
    return labels[key] ?? key;
  }

  Future<void> _runAction(ModuleAction action, Map<String, dynamic> item) async {
    if (action.type == ModuleActionType.whatsapp) {
      final phone = '${item['phone'] ?? item['whatsapp'] ?? item['clientPhone'] ?? ''}';
      if (phone.trim().isEmpty) {
        _snack('Registro sem WhatsApp.');
        return;
      }
      final opened = await ExternalLinks.openWhatsApp(phone);
      if (!opened) _snack('Não foi possível abrir o WhatsApp.');
      return;
    }

    if (action.confirmMessage != null) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(action.label),
              content: Text(action.confirmMessage!),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }

    try {
      final result = await GetIt.I<ApiClient>().cloud(action.function!, {
        'id': _idOf(item),
        ...action.payload,
      });
      if (action.openReturnedUrl) {
        final url = result['url'] ?? result['pdfUrl'] ?? result['downloadUrl'] ?? result['fileUrl'];
        if (url == null || '$url'.isEmpty) {
          _snack('Documento gerado, mas o backend não retornou a URL.');
        } else {
          final opened = await ExternalLinks.openUrl('$url');
          if (!opened) _snack('Não foi possível abrir o documento.');
        }
      } else {
        _snack('${action.label} concluído.');
      }
      await _load();
    } catch (e) {
      _snack('Erro: $e');
    }
  }

  Future<void> _showForm({Map<String, dynamic>? item}) async {
    final editing = item != null;
    final controllers = <String, TextEditingController>{};
    final files = <String, PlatformFile>{};
    for (final field in widget.fields) {
      if (field.type != ModuleFieldType.file) {
        controllers[field.key] = TextEditingController(text: item?[field.key]?.toString() ?? '');
      }
    }
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocalState) {
          Future<void> chooseFile(ModuleField field) async {
            final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
            if (result == null || result.files.isEmpty) return;
            final file = result.files.first;
            if (file.bytes == null) {
              _snack('Não foi possível ler o arquivo selecionado.');
              return;
            }
            if (file.size > 12 * 1024 * 1024) {
              _snack('Arquivo muito grande. Limite: 12 MB.');
              return;
            }
            setLocalState(() => files[field.key] = file);
          }

          Future<void> save() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            for (final field in widget.fields.where((field) => field.type == ModuleFieldType.file && field.required)) {
              if (!editing && files[field.key] == null) {
                _snack('Selecione ${field.label}.');
                return;
              }
            }

            setLocalState(() => saving = true);
            try {
              final payload = <String, dynamic>{if (editing) 'id': _idOf(item)};
              for (final field in widget.fields) {
                if (field.type == ModuleFieldType.file) {
                  final file = files[field.key];
                  if (file != null && file.bytes != null) {
                    payload[field.key] = {'name': file.name, 'base64': base64Encode(file.bytes!)};
                  }
                } else {
                  payload[field.key] = controllers[field.key]!.text.trim();
                }
              }

              await GetIt.I<ApiClient>().cloud(editing ? widget.updateFunction! : widget.createFunction!, payload);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _snack(editing ? 'Registro atualizado.' : 'Registro criado.');
              await _load();
            } catch (e) {
              _snack('Erro: $e');
            } finally {
              if (dialogContext.mounted) setLocalState(() => saving = false);
            }
          }

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(editing ? Icons.edit_outlined : Icons.add, color: AppColors.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(editing ? 'Editar registro' : 'Novo registro', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(widget.title, style: const TextStyle(fontSize: 12, color: AppColors.silverDark)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        for (final field in widget.fields) ...[
                          if (field.type == ModuleFieldType.file)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: saving ? null : () => chooseFile(field),
                                icon: const Icon(Icons.attach_file),
                                label: Text(files[field.key]?.name ?? field.label),
                              ),
                            )
                          else
                            TextFormField(
                              controller: controllers[field.key],
                              minLines: field.type == ModuleFieldType.multiline ? 3 : 1,
                              maxLines: field.type == ModuleFieldType.multiline ? 6 : 1,
                              keyboardType: _keyboardType(field.type),
                              validator: field.required
                                  ? (value) => value == null || value.trim().isEmpty ? 'Campo obrigatório.' : null
                                  : null,
                              decoration: InputDecoration(
                                labelText: field.label,
                                suffixIcon: field.type == ModuleFieldType.date ? const Icon(Icons.event_outlined) : null,
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(editing ? 'Salvar alterações' : 'Criar registro'),
              ),
            ],
          );
        },
      ),
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  TextInputType _keyboardType(ModuleFieldType type) {
    switch (type) {
      case ModuleFieldType.phone:
        return TextInputType.phone;
      case ModuleFieldType.number:
      case ModuleFieldType.money:
        return const TextInputType.numberWithOptions(decimal: true);
      default:
        return TextInputType.text;
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir registro'),
            content: const Text('Confirma a exclusão? As regras de segurança do backend serão aplicadas.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await GetIt.I<ApiClient>().cloud(widget.deleteFunction!, {'id': _idOf(item)});
      _snack('Registro excluído.');
      await _load();
    } catch (e) {
      _snack('Erro: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

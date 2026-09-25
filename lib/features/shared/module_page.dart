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
  String? _status;
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
        if ((_status ?? '').isNotEmpty) 'status': _status,
      });
      final raw = result['items'] ?? result['data'] ?? result['results'] ?? const [];
      if (mounted) setState(() => items = raw is List ? raw : [raw]);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _idOf(Map<String, dynamic> item) =>
      '${item['objectId'] ?? item['id'] ?? ''}';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(widget.subtitle,
                        style: const TextStyle(color: AppColors.silverDark)),
                  ],
                ),
              ),
              if (widget.allowCreate && widget.createFunction != null)
                FilledButton.icon(
                  onPressed: () => _showForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo'),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _filters(),
          const SizedBox(height: 16),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            _errorCard()
          else if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(36),
                child: Center(
                  child: Text('Nenhum registro encontrado.',
                      style: TextStyle(color: AppColors.silverDark)),
                ),
              ),
            )
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

  Widget _filters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                DropdownMenuItem(value: null, child: Text('Todos')),
                DropdownMenuItem(value: 'Novo', child: Text('Novo')),
                DropdownMenuItem(
                    value: 'Em atendimento', child: Text('Em atendimento')),
                DropdownMenuItem(
                    value: 'Aguardando cliente',
                    child: Text('Aguardando cliente')),
                DropdownMenuItem(
                    value: 'Aguardando', child: Text('Aguardando')),
                DropdownMenuItem(
                    value: 'Em Produção', child: Text('Em Produção')),
                DropdownMenuItem(
                    value: 'Concluído', child: Text('Concluído')),
                DropdownMenuItem(
                    value: 'Cancelado', child: Text('Cancelado')),
              ],
              onChanged: (value) {
                setState(() => _status = value);
                _load();
              },
            );
            final refresh = IconButton.filledTonal(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar',
            );

            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: status),
                    const SizedBox(width: 10),
                    refresh,
                  ]),
                ],
              );
            }
            return Row(children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              Expanded(child: status),
              const SizedBox(width: 10),
              refresh,
            ]);
          },
        ),
      ),
    );
  }

  Widget _errorCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.cloud_off_outlined,
                color: AppColors.gold, size: 42),
            const SizedBox(height: 10),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ]),
        ),
      );

  Widget _recordCard(Map<String, dynamic> item) {
    final title = item['name'] ??
        item['clientName'] ??
        item['number'] ??
        item['title'] ??
        item['serviceType'] ??
        'Registro';
    final status = item['status']?.toString();
    final origin = item['origin']?.toString();
    final subtitle = item['phone'] ??
        item['description'] ??
        item['cityAddress'] ??
        item['value'] ??
        '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF2A2412),
            child: Icon(Icons.folder_open_outlined, color: AppColors.gold),
          ),
          title: Text('$title',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('$subtitle'),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.originBadge && origin != null && origin.isNotEmpty)
                Chip(label: Text('Origem: $origin')),
              if (status != null && status.isNotEmpty)
                Chip(label: Text(status)),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => _showDetails(item),
        ),
      ),
    );
  }

  Future<void> _showDetails(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...item.entries
                    .where((entry) =>
                        !entry.key.startsWith('_') &&
                        !entry.key.toLowerCase().contains('base64'))
                    .map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.key,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.silverDark)),
                              const SizedBox(height: 2),
                              Text('${entry.value}'),
                            ],
                          ),
                        )),
                if (widget.actions.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),
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
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _runAction(
      ModuleAction action, Map<String, dynamic> item) async {
    if (action.type == ModuleActionType.whatsapp) {
      final phone =
          '${item['phone'] ?? item['whatsapp'] ?? item['clientPhone'] ?? ''}';
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
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Confirmar')),
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
        final url = result['url'] ??
            result['pdfUrl'] ??
            result['downloadUrl'] ??
            result['fileUrl'];
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
        controllers[field.key] = TextEditingController(
          text: item?[field.key]?.toString() ?? '',
        );
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
            final result = await FilePicker.platform.pickFiles(
              allowMultiple: false,
              withData: true,
            );
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
            for (final field in widget.fields.where((field) =>
                field.type == ModuleFieldType.file && field.required)) {
              if (!editing && files[field.key] == null) {
                _snack('Selecione ${field.label}.');
                return;
              }
            }

            setLocalState(() => saving = true);
            try {
              final payload = <String, dynamic>{
                if (editing) 'id': _idOf(item),
              };
              for (final field in widget.fields) {
                if (field.type == ModuleFieldType.file) {
                  final file = files[field.key];
                  if (file != null && file.bytes != null) {
                    payload[field.key] = {
                      'name': file.name,
                      'base64': base64Encode(file.bytes!),
                    };
                  }
                } else {
                  payload[field.key] = controllers[field.key]!.text.trim();
                }
              }

              await GetIt.I<ApiClient>().cloud(
                editing ? widget.updateFunction! : widget.createFunction!,
                payload,
              );
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
            title: Text(editing
                ? 'Editar - ${widget.title}'
                : 'Novo - ${widget.title}'),
            content: SizedBox(
              width: 620,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final field in widget.fields) ...[
                        if (field.type == ModuleFieldType.file)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed:
                                  saving ? null : () => chooseFile(field),
                              icon: const Icon(Icons.attach_file),
                              label:
                                  Text(files[field.key]?.name ?? field.label),
                            ),
                          )
                        else
                          TextFormField(
                            controller: controllers[field.key],
                            minLines: field.type == ModuleFieldType.multiline
                                ? 3
                                : 1,
                            maxLines: field.type == ModuleFieldType.multiline
                                ? 6
                                : 1,
                            keyboardType: _keyboardType(field.type),
                            validator: field.required
                                ? (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Campo obrigatório.'
                                        : null
                                : null,
                            decoration: InputDecoration(
                              labelText: field.label,
                              suffixIcon: field.type == ModuleFieldType.date
                                  ? const Icon(Icons.event_outlined)
                                  : null,
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(editing ? 'Salvar' : 'Criar'),
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
            content: const Text(
                'Confirma a exclusão? As regras do backend ainda serão aplicadas.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Excluir')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await GetIt.I<ApiClient>().cloud(widget.deleteFunction!, {
        'id': _idOf(item),
      });
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

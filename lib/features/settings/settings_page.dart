import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _tradeName = TextEditingController();
  final _legalName = TextEditingController();
  final _cnpj = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _pixKey = TextEditingController();
  final _paymentTerms = TextEditingController();
  final _footer = TextEditingController();

  bool loading = true;
  bool saving = false;
  Object? error;
  String? _logoUrl;
  PlatformFile? _logoFile;

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
      final result =
          await GetIt.I<ApiClient>().cloud('v1-company-settings-get');
      _tradeName.text = '${result['tradeName'] ?? ''}';
      _legalName.text = '${result['legalName'] ?? ''}';
      _cnpj.text = '${result['cnpj'] ?? ''}';
      _address.text = '${result['address'] ?? ''}';
      _email.text = '${result['email'] ?? ''}';
      _phone.text = '${result['phone'] ?? ''}';
      _whatsapp.text = '${result['whatsapp'] ?? ''}';
      _pixKey.text = '${result['pixKey'] ?? ''}';
      _paymentTerms.text = '${result['paymentTerms'] ?? ''}';
      _footer.text = '${result['documentFooter'] ?? ''}';
      if (mounted) {
        setState(() {
          _logoUrl = result['logoUrl']?.toString();
          _logoFile = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _snack('Não foi possível ler a imagem selecionada.');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      _snack('A logo deve ter no máximo 5 MB.');
      return;
    }
    setState(() => _logoFile = file);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      final payload = <String, dynamic>{
        'tradeName': _tradeName.text.trim(),
        'legalName': _legalName.text.trim(),
        'cnpj': _cnpj.text.trim(),
        'address': _address.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'pixKey': _pixKey.text.trim(),
        'paymentTerms': _paymentTerms.text.trim(),
        'documentFooter': _footer.text.trim(),
      };

      if (_logoFile?.bytes != null) {
        payload['logo'] = {
          'name': _logoFile!.name,
          'base64': base64Encode(_logoFile!.bytes!),
        };
      }

      final result = await GetIt.I<ApiClient>()
          .cloud('v1-company-settings-update', payload);
      if (!mounted) return;
      setState(() {
        _logoUrl = result['logoUrl']?.toString() ?? _logoUrl;
        _logoFile = null;
      });
      _snack('Configurações salvas.');
    } catch (e) {
      _snack('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    _tradeName.dispose();
    _legalName.dispose();
    _cnpj.dispose();
    _address.dispose();
    _email.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _pixKey.dispose();
    _paymentTerms.dispose();
    _footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Configurações da empresa',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Dados usados pelo sistema, orçamentos, contratos e demais documentos.',
          style: TextStyle(color: AppColors.silverDark),
        ),
        const SizedBox(height: 20),
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
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final preview = Container(
                          width: 140,
                          height: 110,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: _logoFile?.bytes != null
                              ? Image.memory(_logoFile!.bytes!, fit: BoxFit.contain)
                              : (_logoUrl != null && _logoUrl!.isNotEmpty)
                                  ? Image.network(
                                      _logoUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        'assets/images/brilhart_logo.png',
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/brilhart_logo.png',
                                      fit: BoxFit.contain,
                                    ),
                        );
                        final info = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Logo da empresa',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Usada no sistema e nos documentos gerados. Formatos de imagem comuns, até 5 MB.',
                              style: TextStyle(color: AppColors.silverDark),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: saving ? null : _pickLogo,
                              icon: const Icon(Icons.upload_outlined),
                              label: Text(_logoFile == null
                                  ? 'Trocar logo'
                                  : _logoFile!.name),
                            ),
                          ],
                        );

                        if (constraints.maxWidth < 620) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              preview,
                              const SizedBox(height: 14),
                              info,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            preview,
                            const SizedBox(width: 18),
                            Expanded(child: info),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    _field(_tradeName, 'Nome comercial', required: true),
                    _field(_legalName, 'Razão social'),
                    _field(_cnpj, 'CNPJ'),
                    _field(_address, 'Endereço'),
                    _field(_email, 'E-mail',
                        keyboardType: TextInputType.emailAddress),
                    _field(_phone, 'Telefone',
                        keyboardType: TextInputType.phone),
                    _field(_whatsapp, 'WhatsApp comercial',
                        keyboardType: TextInputType.phone),
                    _field(_pixKey, 'Chave Pix'),
                    _field(
                      _paymentTerms,
                      'Condições padrão de pagamento',
                      minLines: 3,
                      maxLines: 5,
                    ),
                    _field(
                      _footer,
                      'Rodapé dos documentos',
                      minLines: 3,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: saving ? null : _save,
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Salvar configurações'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? 'Campo obrigatório.'
                : null
            : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

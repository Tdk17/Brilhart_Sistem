import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brilhart_logo.dart';

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
      final result = await GetIt.I<ApiClient>().cloud('v1-company-settings-get');
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

      final result = await GetIt.I<ApiClient>().cloud('v1-company-settings-update', payload);
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
              child: const Icon(Icons.settings_outlined, color: AppColors.gold),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configurações da empresa', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text(
                    'Identidade, dados comerciais e informações usadas em documentos.',
                    style: TextStyle(color: AppColors.silverDark),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (loading)
          _stateCard(const CircularProgressIndicator(), 'Carregando configurações...')
        else if (error != null)
          _errorCard()
        else
          Form(
            key: _formKey,
            child: Column(
              children: [
                _identityCard(),
                const SizedBox(height: 16),
                _businessCard(),
                const SizedBox(height: 16),
                _documentsCard(),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Salvar configurações'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _identityCard() {
    return _section(
      title: 'Identidade da empresa',
      subtitle: 'Logo e identificação comercial exibidas no sistema e nos documentos.',
      icon: Icons.storefront_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preview = Container(
            width: 180,
            height: 132,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: _logoFile?.bytes != null
                ? Image.memory(_logoFile!.bytes!, fit: BoxFit.contain)
                : (_logoUrl != null && _logoUrl!.isNotEmpty)
                    ? Image.network(
                        _logoUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const BrilhartLogo(height: 100),
                      )
                    : const BrilhartLogo(height: 100),
          );

          final form = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(_tradeName, 'Nome comercial', required: true),
              _field(_legalName, 'Razão social'),
              _field(_cnpj, 'CNPJ'),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: saving ? null : _pickLogo,
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(_logoFile == null ? 'Trocar logo' : _logoFile!.name),
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [preview, const SizedBox(height: 18), form],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [preview, const SizedBox(width: 22), Expanded(child: form)],
          );
        },
      ),
    );
  }

  Widget _businessCard() {
    return _section(
      title: 'Dados comerciais',
      subtitle: 'Informações usadas para contato, pagamento e identificação da empresa.',
      icon: Icons.business_center_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                _field(_address, 'Endereço'),
                _field(_email, 'E-mail', keyboardType: TextInputType.emailAddress),
                _field(_phone, 'Telefone', keyboardType: TextInputType.phone),
                _field(_whatsapp, 'WhatsApp comercial', keyboardType: TextInputType.phone),
                _field(_pixKey, 'Chave Pix'),
              ],
            );
          }
          return Column(
            children: [
              Row(children: [
                Expanded(child: _field(_address, 'Endereço')),
                const SizedBox(width: 12),
                Expanded(child: _field(_email, 'E-mail', keyboardType: TextInputType.emailAddress)),
              ]),
              Row(children: [
                Expanded(child: _field(_phone, 'Telefone', keyboardType: TextInputType.phone)),
                const SizedBox(width: 12),
                Expanded(child: _field(_whatsapp, 'WhatsApp comercial', keyboardType: TextInputType.phone)),
              ]),
              _field(_pixKey, 'Chave Pix'),
            ],
          );
        },
      ),
    );
  }

  Widget _documentsCard() {
    return _section(
      title: 'Padrões de documentos',
      subtitle: 'Textos aplicados automaticamente nos orçamentos, contratos e fechamentos.',
      icon: Icons.description_outlined,
      child: Column(
        children: [
          _field(_paymentTerms, 'Condições padrão de pagamento', minLines: 3, maxLines: 5),
          _field(_footer, 'Rodapé dos documentos', minLines: 3, maxLines: 5),
        ],
      ),
    );
  }

  Widget _section({required String title, required String subtitle, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 21),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: AppColors.silverDark)),
          const SizedBox(height: 18),
          child,
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
            ? (value) => value == null || value.trim().isEmpty ? 'Campo obrigatório.' : null
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

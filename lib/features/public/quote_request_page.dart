import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brilhart_logo.dart';

class QuoteRequestPage extends StatefulWidget {
  const QuoteRequestPage({super.key});

  @override
  State<QuoteRequestPage> createState() => _QuoteRequestPageState();
}

class _QuoteRequestPageState extends State<QuoteRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _serviceType = TextEditingController();
  final _description = TextEditingController();
  final _measurements = TextEditingController();
  final List<PlatformFile> _photos = [];
  bool _busy = false;
  bool _sent = false;
  String? _error;

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;

    final accepted = result.files
        .where((file) => file.bytes != null && file.size <= 8 * 1024 * 1024)
        .take(8)
        .toList();

    setState(() {
      _photos
        ..clear()
        ..addAll(accepted);
      if (accepted.length != result.files.take(8).length) {
        _error = 'Algumas imagens foram ignoradas. Use até 8 fotos com no máximo 8 MB cada.';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GetIt.I<ApiClient>().cloud('v1-quote-requests-create', {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'cityAddress': _city.text.trim(),
        'serviceType': _serviceType.text.trim(),
        'description': _description.text.trim(),
        'measurements': _measurements.text.trim(),
        'source': 'Site',
        'photos': _photos
            .map((file) => {
                  'name': file.name,
                  'contentType': _contentType(file.name),
                  'base64': base64Encode(file.bytes!),
                })
            .toList(),
      });
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _serviceType.dispose();
    _description.dispose();
    _measurements.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.3,
            colors: [Color(0xFF2A2412), Color(0xFF101010), AppColors.black],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .32),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: _sent ? _success() : _form(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrilhartLogo(height: 94),
          const SizedBox(height: 24),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.task_alt, size: 38, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          const Text('Solicitação enviada', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'A Brilhart recebeu seus dados. Nossa equipe analisará as informações antes de emitir o orçamento oficial.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.silverDark, height: 1.45),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => setState(() => _sent = false),
            icon: const Icon(Icons.add),
            label: const Text('Enviar nova solicitação'),
          ),
        ],
      );

  Widget _form() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: BrilhartLogo(height: 112)),
            const SizedBox(height: 20),
            const Text(
              'Solicitar orçamento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            const Text(
              'Preencha as informações abaixo para nossa equipe avaliar o serviço e preparar uma proposta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.silverDark, height: 1.45),
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _requiredField(_name, 'Nome', Icons.person_outline),
                  const SizedBox(height: 12),
                  _requiredField(_phone, 'WhatsApp', Icons.phone_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _requiredField(_city, 'Cidade / endereço', Icons.location_on_outlined),
                  const SizedBox(height: 12),
                  _requiredField(_serviceType, 'Tipo de serviço', Icons.handyman_outlined),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    minLines: 4,
                    maxLines: 7,
                    validator: (value) => value == null || value.trim().isEmpty ? 'Descreva o serviço.' : null,
                    decoration: const InputDecoration(
                      labelText: 'Descrição do serviço',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _measurements,
                    decoration: const InputDecoration(
                      labelText: 'Medidas / metragem (se souber)',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Fotos do serviço', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('Você pode enviar até 8 imagens, com no máximo 8 MB cada.', style: TextStyle(color: AppColors.silverDark, fontSize: 12)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_photos.isEmpty ? 'Adicionar fotos' : '${_photos.length} foto(s) selecionada(s)'),
                  ),
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _photos.map((e) => Chip(label: Text(e.name, overflow: TextOverflow.ellipsis))).toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 3),
                child: Text('Enviar solicitação'),
              ),
            ),
          ],
        ),
      );

  TextFormField _requiredField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) => value == null || value.trim().isEmpty ? 'Campo obrigatório.' : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

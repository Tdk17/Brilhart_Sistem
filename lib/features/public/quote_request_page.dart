import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';

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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF17130A), AppColors.black],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
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
          const Icon(Icons.task_alt, size: 64, color: AppColors.gold),
          const SizedBox(height: 16),
          const Text(
            'Solicitação enviada',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'A BrilhArte recebeu seus dados. Esta solicitação ainda não é um orçamento oficial; nossa equipe entrará em contato para dar continuidade.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.silverDark),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => setState(() => _sent = false),
            icon: const Icon(Icons.add),
            label: const Text('Nova solicitação'),
          ),
        ],
      );

  Widget _form() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              'assets/images/brilhart_logo.png',
              height: 105,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.format_paint,
                size: 60,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Solicitar orçamento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Envie as informações do serviço. A equipe da BrilhArte analisará a solicitação antes de gerar o orçamento oficial.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.silverDark),
            ),
            const SizedBox(height: 24),
            _requiredField(_name, 'Nome', Icons.person_outline),
            const SizedBox(height: 12),
            _requiredField(
              _phone,
              'WhatsApp',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _requiredField(
                _city, 'Cidade / endereço', Icons.location_on_outlined),
            const SizedBox(height: 12),
            _requiredField(
                _serviceType, 'Tipo de serviço', Icons.handyman_outlined),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 7,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Descreva o serviço.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                alignLabelWithHint: true,
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_photos.isEmpty
                  ? 'Adicionar fotos'
                  : '${_photos.length} foto(s) selecionada(s)'),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _photos
                    .map((e) => Chip(
                          label: Text(e.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
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
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Campo obrigatório.'
          : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

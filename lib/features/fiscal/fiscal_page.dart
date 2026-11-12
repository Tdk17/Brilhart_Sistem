import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../core/services/api_client.dart';
import '../../core/services/external_links.dart';
import '../../core/theme/app_theme.dart';

const fiscalStatusLabels = <String, String>{
  'not_sent': 'Não enviada',
  'processing': 'Em processamento',
  'unknown': 'A confirmar',
  'authorized': 'Autorizada',
  'rejected': 'Rejeitada',
  'denied': 'Negada',
  'cancelling': 'Cancelamento pendente',
  'cancelled': 'Cancelada',
};

String fiscalMoney(dynamic value) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value is num ? value : 0);
Map<String, dynamic> fiscalMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> fiscalRows(dynamic value) => value is List ? value.map(fiscalMap).toList() : [];

/// Fiscal workspace: server data only. Fiscal credentials never reach this widget.
class FiscalPage extends StatefulWidget {
  const FiscalPage({super.key, this.serviceId});
  final String? serviceId;
  @override
  State<FiscalPage> createState() => _FiscalPageState();
}

class _FiscalPageState extends State<FiscalPage> {
  final _api = GetIt.I<ApiClient>();
  Map<String, dynamic> _config = {};
  List<Map<String, dynamic>> _invoices = [];
  String _status = '';
  String? _busyId;
  String? _error;
  bool _loading = true;
  bool _hasMore = false;
  int _offset = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.cloud('v1-fiscal-config-get'),
        _api.cloud('v1-fiscal-invoices-list', {
          'offset': _offset,
          if (_status.isNotEmpty) 'status': _status,
          if (widget.serviceId != null) 'serviceId': widget.serviceId,
        }),
      ]);
      if (!mounted) return;
      setState(() {
        _config = results[0];
        _invoices = fiscalRows(results[1]['items']);
        _hasMore = results[1]['hasMore'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível carregar o módulo fiscal. $e');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _snack(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _newInvoice({Map<String, dynamic>? previous}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IssueDialog(config: _config,
        serviceId: previous?['serviceId']?.toString() ?? widget.serviceId,
        previous: previous),
    );
    if (result == true && mounted) await _load();
  }

  Future<void> _perform(Map<String, dynamic> invoice, String action) async {
    final id = invoice['id'].toString();
    String? reason;
    if (action == 'cancel') {
      reason = await showDialog<String>(context: context, builder: (_) => const _CancellationDialog());
      if (reason == null || !mounted) return;
    }
    setState(() => _busyId = id);
    try {
      if (action == 'pdf' || action == 'xml') {
        final result = await _api.cloud('v1-fiscal-invoices-download', {'id': id, 'kind': action});
        await FilePicker.platform.saveFile(
          dialogTitle: 'Salvar documento fiscal', fileName: result['fileName'] as String,
          type: FileType.custom, allowedExtensions: [action],
          bytes: base64Decode(result['base64'] as String),
        );
      } else {
        final result = await _api.cloud('v1-fiscal-invoices-$action', {'id': id, if (reason != null) 'reason': reason});
        _snack(fiscalStatusLabels[result['status']] ?? 'Situação atualizada.');
        await _load();
      }
    } catch (e) { _snack('$e'); }
    finally { if (mounted) setState(() => _busyId = null); }
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_loading && _error == null && _config['ready'] == true;
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
      children: [
        Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 16, spacing: 24, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FINANCEIRO / FISCAL', style: TextStyle(color: AppColors.primary, fontSize: 11, letterSpacing: 1.8, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Notas fiscais', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Emissão e acompanhamento de NFS-e dos serviços.', style: TextStyle(color: AppColors.textMuted)),
          ]),
          FilledButton.icon(onPressed: ready ? () => _newInvoice() : null,
            icon: const Icon(Icons.add), label: const Text('Emitir NFS-e')),
        ]),
        const SizedBox(height: 24),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) _Notice(message: _error!, action: TextButton(onPressed: _load, child: const Text('Tentar novamente'))),
        if (!_loading && _error == null) ...[
          _Notice(
            message: _config['ready'] == true
              ? '${fiscalMap(_config['issuer'])['legalName'] ?? 'Empresa'} • ${_config['environment'] == 'producao' ? 'Produção — emissão com validade fiscal após autorização' : 'Homologação — notas de teste, sem valor fiscal'}'
              : 'Configuração fiscal pendente: ${(_config['missing'] as List? ?? []).join(' • ')}.',
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _Metric(label: 'Registros nesta página', value: '${_invoices.length}', icon: Icons.receipt_long_outlined),
            _Metric(label: 'Autorizadas nesta página', value: '${_invoices.where((e) => e['status'] == 'authorized').length}', icon: Icons.verified_outlined),
            _Metric(label: 'Acompanhar nesta página', value: '${_invoices.where((e) => ['unknown', 'processing', 'cancelling'].contains(e['status'])).length}', icon: Icons.schedule),
          ]),
          const SizedBox(height: 24),
          Wrap(spacing: 14, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 260, child: DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Situação fiscal', prefixIcon: Icon(Icons.filter_alt_outlined)),
              items: [const DropdownMenuItem(value: '', child: Text('Todas as situações')),
                ...fiscalStatusLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))],
              onChanged: _busyId != null ? null : (value) { setState(() { _status = value ?? ''; _offset = 0; }); _load(); },
            )),
            OutlinedButton.icon(onPressed: _busyId != null ? null : _load, icon: const Icon(Icons.refresh), label: const Text('Atualizar lista')),
            if (widget.serviceId != null) const Chip(label: Text('Vinculadas ao serviço selecionado')),
          ]),
          const SizedBox(height: 18),
          if (_invoices.isEmpty)
            const _Notice(message: 'Nenhuma nota encontrada. Selecione um serviço concluído para iniciar a emissão.')
          else ..._invoices.map(_invoiceCard),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('Página ${_offset ~/ 30 + 1}', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(width: 12),
            IconButton(tooltip: 'Página anterior', onPressed: _offset > 0 && _busyId == null ? () { _offset -= 30; _load(); } : null, icon: const Icon(Icons.chevron_left)),
            IconButton(tooltip: 'Próxima página', onPressed: _hasMore && _busyId == null ? () { _offset += 30; _load(); } : null, icon: const Icon(Icons.chevron_right)),
          ]),
        ],
      ],
    );
  }

  Widget _invoiceCard(Map<String, dynamic> invoice) {
    final summary = fiscalMap(invoice['summary']);
    final status = '${invoice['status']}';
    final busy = _busyId != null;
    final color = status == 'authorized' ? AppColors.success : ['rejected', 'denied'].contains(status) ? AppColors.danger : AppColors.primary;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Icon(Icons.receipt_long_outlined, color: color),
          Text(invoice['number']?.toString().isNotEmpty == true ? 'NFS-e ${invoice['number']}' : 'NFS-e em acompanhamento', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          Chip(label: Text(fiscalStatusLabels[status] ?? 'A confirmar', style: TextStyle(color: color))),
          Text(invoice['environment'] == 'producao' ? 'PRODUÇÃO' : 'HOMOLOGAÇÃO', style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1)),
        ]),
        const SizedBox(height: 12),
        Text('${fiscalMap(summary['recipient'])['name'] ?? summary['clientName'] ?? ''} • ${fiscalMoney(summary['value'])}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('${summary['description'] ?? ''}', style: const TextStyle(color: AppColors.textMuted)),
        if ('${invoice['message'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('${invoice['message']}', style: const TextStyle(color: AppColors.warning))),
        if (status == 'cancelled') const Padding(padding: EdgeInsets.only(top: 8), child: Text('Nota cancelada. Documentos disponíveis apenas para consulta do histórico.')),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: busy ? null : () => _perform(invoice, 'refresh'), icon: const Icon(Icons.sync, size: 18), label: const Text('Consultar situação')),
          if (['authorized', 'cancelled'].contains(status)) ...[
            TextButton.icon(onPressed: busy || invoice['canDownloadPdf'] != true ? null : () => _perform(invoice, 'pdf'), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF')),
            TextButton.icon(onPressed: busy || invoice['canDownloadXml'] != true ? null : () => _perform(invoice, 'xml'), icon: const Icon(Icons.code), label: const Text('XML')),
            if ('${invoice['consultationUrl'] ?? ''}'.isNotEmpty)
              TextButton.icon(onPressed: busy ? null : () async {
                if (!await ExternalLinks.openUrl('${invoice['consultationUrl']}')) _snack('Não foi possível abrir o portal.');
              }, icon: const Icon(Icons.open_in_new), label: const Text('Consultar no portal')),
          ],
          if (['rejected', 'not_sent'].contains(status)) TextButton(onPressed: busy || _config['ready'] != true ? null : () => _newInvoice(previous: invoice), child: const Text('Revisar e reenviar')),
          if (status == 'authorized') TextButton(onPressed: busy ? null : () => _perform(invoice, 'cancel'), child: const Text('Solicitar cancelamento')),
        ]),
        if (_busyId == invoice['id']) const LinearProgressIndicator(),
      ]),
    )));
  }
}

class _IssueDialog extends StatefulWidget {
  const _IssueDialog({required this.config, this.serviceId, this.previous});
  final Map<String, dynamic> config;
  final String? serviceId;
  final Map<String, dynamic>? previous;
  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  final _api = GetIt.I<ApiClient>();
  final _form = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _fields = <String, TextEditingController>{};
  List<Map<String, dynamic>> _services = [];
  Map<String, dynamic>? _service;
  Map<String, dynamic>? _preview;
  String? _profile;
  String? _error;
  bool _busy = true;
  final _labels = const {
    'name': 'Nome / razão social do cliente', 'document': 'CPF / CNPJ',
    'street': 'Logradouro', 'number': 'Número', 'district': 'Bairro',
    'municipalityCode': 'Código IBGE do município do cliente', 'state': 'UF',
    'postalCode': 'CEP', 'email': 'E-mail (opcional)',
    'serviceMunicipality': 'Código IBGE do local da prestação', 'competence': 'Competência (AAAA-MM-DD)',
  };

  @override
  void initState() {
    super.initState();
    for (final key in _labels.keys) { _fields[key] = TextEditingController(); }
    final old = fiscalMap(widget.previous?['summary']);
    _fields['competence']!.text = '${old['competence'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    _fields['serviceMunicipality']!.text = '${old['serviceMunicipality'] ?? fiscalMap(widget.config['issuer'])['municipalityCode'] ?? ''}';
    _loadServices();
  }

  @override
  void dispose() { _search.dispose(); for (final c in _fields.values) { c.dispose(); } super.dispose(); }

  List<Map<String, dynamic>> get _profiles => fiscalRows(widget.config['profiles']).where((p) => (p['serviceTypes'] as List? ?? []).contains(_service?['serviceType'])).toList();

  void _select(Map<String, dynamic> service) {
    _service = service;
    final old = fiscalMap(widget.previous?['summary']);
    final r = widget.previous != null && service['id'] == widget.serviceId ? fiscalMap(old['recipient']) : fiscalMap(service['recipient']);
    for (final key in _labels.keys.where((k) => !['competence', 'serviceMunicipality'].contains(k))) { _fields[key]!.text = '${r[key] ?? ''}'; }
    _profile = _profiles.any((p) => p['id'] == old['profileId']) ? old['profileId'] as String : _profiles.length == 1 ? _profiles.first['id'] as String : null;
  }

  Future<void> _loadServices() async {
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _api.cloud('v1-fiscal-services-list', {'search': _search.text.trim(), if (widget.serviceId != null) 'serviceId': widget.serviceId});
      if (!mounted) return;
      setState(() {
        _services = fiscalRows(result['items']);
        if (_service == null && widget.serviceId != null) {
          final matches = _services.where((s) => s['id'] == widget.serviceId);
          if (matches.isNotEmpty) _select(matches.first);
        }
      });
    } catch (e) { if (mounted) setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Map<String, dynamic> _input() => {
    'serviceId': _service?['id'], 'profileId': _profile,
    'competence': _fields['competence']!.text.trim(),
    'serviceMunicipality': _fields['serviceMunicipality']!.text.trim(),
    'recipient': {for (final key in _labels.keys.where((k) => !['competence', 'serviceMunicipality'].contains(k))) key: _fields[key]!.text.trim()},
  };

  Future<void> _submit() async {
    if (_preview == null && !(_form.currentState?.validate() ?? false)) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_preview == null) {
        final result = await _api.cloud('v1-fiscal-invoices-preview', _input());
        if (mounted) setState(() => _preview = result);
      } else {
        await _api.cloud('v1-fiscal-invoices-issue', {..._input(), 'previewHash': _preview!['previewHash']});
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) { if (mounted) setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final summary = fiscalMap(_preview?['summary']);
    return PopScope(canPop: !_busy, child: AlertDialog(
      title: Text(_preview == null ? 'Preparar NFS-e' : 'Conferir emissão'),
      content: SizedBox(width: 700, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
        if (_preview != null) ...[
          _Notice(message: widget.config['environment'] == 'producao' ? 'Ao confirmar, esta NFS-e será enviada para autorização fiscal.' : 'Emissão em homologação. Esta nota não terá valor fiscal.'),
          const SizedBox(height: 16),
          Text('${fiscalMap(summary['recipient'])['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('CPF/CNPJ: ${fiscalMap(summary['recipient'])['document']}'),
          const SizedBox(height: 12),
          Text('${summary['description']}'),
          const SizedBox(height: 12),
          Text(fiscalMoney(summary['value']), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 12),
          Text('Competência: ${summary['competence']}\nEnquadramento: ${summary['profileLabel']}\nEmitente: ${fiscalMap(summary['issuer'])['legalName']}'),
          const SizedBox(height: 12),
          const Text('O resultado será acompanhado na central fiscal. A nota só é autorizada após confirmação do órgão emissor.', style: TextStyle(color: AppColors.textMuted)),
        ] else Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _search, enabled: !_busy, onSubmitted: (_) => _loadServices(), decoration: InputDecoration(labelText: 'Buscar serviço concluído pela descrição', suffixIcon: IconButton(onPressed: _busy ? null : _loadServices, icon: const Icon(Icons.search)))),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey(_services.map((s) => s['id']).join()),
            initialValue: _services.any((s) => s['id'] == _service?['id']) ? (_service?['id'] as String?) : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Serviço concluído'),
            items: _services.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text('${s['clientName']} • ${s['description']}', overflow: TextOverflow.ellipsis))).toList(),
            validator: (v) => v == null ? 'Selecione um serviço.' : null,
            onChanged: _busy ? null : (value) => setState(() => _select(_services.firstWhere((s) => s['id'] == value))),
          ),
          if (_services.isEmpty && !_busy) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Nenhum serviço concluído encontrado.')),
          const SizedBox(height: 14),
          if (_service != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text('Valor do serviço: ${fiscalMoney(_service!['value'])}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          DropdownButtonFormField<String>(
            key: ValueKey('${_service?['id']}:$_profile'), initialValue: _profile, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Enquadramento fiscal'),
            items: _profiles.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text('${p['label']}'))).toList(),
            validator: (v) => v == null ? 'Selecione um enquadramento fiscal.' : null,
            onChanged: _busy ? null : (value) => setState(() => _profile = value),
          ),
          const SizedBox(height: 18),
          ..._labels.entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
            controller: _fields[entry.key], enabled: !_busy, decoration: InputDecoration(labelText: entry.value),
            textCapitalization: ['state', 'document'].contains(entry.key) ? TextCapitalization.characters : TextCapitalization.none,
            validator: (value) => entry.key != 'email' && (value == null || value.trim().isEmpty) ? 'Preencha este campo.' : null,
          ))),
        ])),
      ]))),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Fechar')),
        if (_preview != null) TextButton(onPressed: _busy ? null : () => setState(() => _preview = null), child: const Text('Editar dados')),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_preview == null ? 'Conferir dados' : 'Confirmar emissão')),
      ],
    ));
  }
}

class _CancellationDialog extends StatefulWidget {
  const _CancellationDialog();
  @override
  State<_CancellationDialog> createState() => _CancellationDialogState();
}
class _CancellationDialogState extends State<_CancellationDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() { _reason.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Solicitar cancelamento da NFS-e'),
    content: SizedBox(width: 480, child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('O cancelamento depende das regras do órgão emissor e, quando autorizado, é definitivo.'),
      const SizedBox(height: 16),
      TextFormField(controller: _reason, maxLength: 255, maxLines: 3, decoration: const InputDecoration(labelText: 'Justificativa'), validator: (v) => (v?.trim().length ?? 0) < 15 ? 'Informe pelo menos 15 caracteres.' : null),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar')),
      FilledButton(onPressed: () { if (_form.currentState!.validate()) Navigator.pop(context, _reason.text.trim()); }, child: const Text('Confirmar solicitação'))],
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(message, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)), if (action != null) action!]),
  );
}
class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 240, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.primary, size: 24), const SizedBox(height: 14),
      Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4), Text(label, style: const TextStyle(color: AppColors.textMuted)),
    ]),
  );
}

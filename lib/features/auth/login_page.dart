import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Informe e-mail e senha.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GetIt.I<AuthService>().login(_email.text, _password.text);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  static const _desktopDownloadUrl = String.fromEnvironment('DESKTOP_DOWNLOAD_URL');

  Future<void> _downloadDesktop() async {
    if (_desktopDownloadUrl.isEmpty) return;
    final url = Uri.tryParse(_desktopDownloadUrl);
    if (url == null || !['https', 'http'].contains(url.scheme)) return;
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'Não foi possível abrir o download do Windows.');
    }
  }

  Widget _brandPanel() => Padding(
    padding: const EdgeInsets.all(48),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 68, height: 68,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primaryDark),
          ),
          child: Image.asset('assets/images/brilhart_logo.png', fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.precision_manufacturing_outlined, color: AppColors.primary, size: 34)),
        ),
        const SizedBox(height: 36),
        const Text('BRILHART  /  GESTÃO EMPRESARIAL',
          style: TextStyle(color: AppColors.primary, letterSpacing: 2.4, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        const Text('Toda a operação.\nUm só lugar.',
          style: TextStyle(fontSize: 42, height: 1.12, fontWeight: FontWeight.w900, color: AppColors.white)),
        const SizedBox(height: 20),
        const Text('Orçamentos, produção, clientes e documentos em um ambiente de trabalho integrado.',
          style: TextStyle(fontSize: 16, height: 1.6, color: AppColors.textSecondary)),
        const SizedBox(height: 42),
        const Wrap(spacing: 12, runSpacing: 12, children: [
          _Benefit(icon: Icons.assignment_turned_in_outlined, text: 'Fluxo operacional'),
          _Benefit(icon: Icons.query_stats_outlined, text: 'Indicadores em tempo real'),
          _Benefit(icon: Icons.shield_outlined, text: 'Acesso autorizado'),
        ]),
      ],
    ),
  );

  Widget _loginPanel() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 440),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('ÁREA RESTRITA', style: TextStyle(
          color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(height: 14),
        const Text('Bem-vindo de volta',
          style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: AppColors.white)),
        const SizedBox(height: 8),
        const Text('Acesse sua área de trabalho Brilhart.',
          style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 32),
        TextField(
          controller: _email, enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          decoration: const InputDecoration(labelText: 'E-mail corporativo',
            prefixIcon: Icon(Icons.alternate_email)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _password, enabled: !_busy,
          obscureText: _hidePassword,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Senha', prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _hidePassword ? 'Mostrar senha' : 'Ocultar senha',
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger.withValues(alpha: .35))),
            child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
        ],
        const SizedBox(height: 26),
        SizedBox(height: 52, child: FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.arrow_forward_rounded),
          label: const Text('Entrar no sistema'),
        )),
        const SizedBox(height: 30),
        const Row(children: [
          Expanded(child: Divider()),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('APLICATIVO PARA COMPUTADOR',
              style: TextStyle(fontSize: 10, letterSpacing: 1, color: AppColors.textMuted))),
          Expanded(child: Divider()),
        ]),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _desktopDownloadUrl.isEmpty ? null : _downloadDesktop,
          icon: const Icon(Icons.desktop_windows_outlined),
          label: Text(_desktopDownloadUrl.isEmpty
            ? 'Versão Windows em preparação'
            : 'Baixar aplicativo para Windows'),
        ),
        const SizedBox(height: 8),
        const Text('O download ficará disponível após a publicação do instalador Windows.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 28),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline, size: 15, color: AppColors.textMuted),
          SizedBox(width: 7),
          Flexible(child: Text('Ambiente exclusivo para usuários autorizados.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
        ]),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF071321), Color(0xFF10233B), AppColors.background])),
        child: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 36 : 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: .30),
                      blurRadius: 40, offset: const Offset(0, 16))]),
                  child: wide
                    ? Row(children: [
                        Expanded(child: Container(
                          constraints: const BoxConstraints(minHeight: 660),
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
                            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [Color(0xFF0A1C31), Color(0xFF17375B)])),
                          child: _brandPanel())),
                        Expanded(child: Padding(padding: const EdgeInsets.all(48), child: Center(child: _loginPanel()))),
                      ])
                    : Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                        child: _loginPanel()),
                ),
              ),
            ),
          );
        })),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
      color: AppColors.surface.withValues(alpha: .75)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 17, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ]),
  );
}

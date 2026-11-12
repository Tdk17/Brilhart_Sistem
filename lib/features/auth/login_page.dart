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
  static const _desktopDownloadUrl = String.fromEnvironment('DESKTOP_DOWNLOAD_URL');
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Informe e-mail e senha.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await GetIt.I<AuthService>().login(_email.text.trim(), _password.text);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadDesktop() async {
    final url = Uri.tryParse(_desktopDownloadUrl);
    if (url == null || url.scheme != 'https') return;
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'Não foi possível abrir o download do Windows.');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(
                  width: 64, height: 64,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Image.asset('assets/images/brilhart_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                      const Icon(Icons.business_outlined, size: 30, color: AppColors.primary)),
                )),
                const SizedBox(height: 24),
                const Text('Brilhart',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Acesso à gestão operacional',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                const SizedBox(height: 36),
                const Text('E-mail', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _email,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'seu@email.com'),
                ),
                const SizedBox(height: 20),
                const Text('Senha', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Digite sua senha',
                    suffixIcon: IconButton(
                      tooltip: _hidePassword ? 'Mostrar senha' : 'Ocultar senha',
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(_hidePassword
                        ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 26),
                SizedBox(height: 48, child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Entrar'),
                )),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                if (_desktopDownloadUrl.isNotEmpty)
                  TextButton.icon(
                    onPressed: _downloadDesktop,
                    icon: const Icon(Icons.desktop_windows_outlined, size: 19),
                    label: const Text('Baixar para Windows'),
                  )
                else
                  const Text('Aplicativo Windows em preparação',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                const Text('Acesso exclusivo a usuários autorizados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

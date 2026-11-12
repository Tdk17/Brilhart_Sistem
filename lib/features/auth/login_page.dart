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
  static const _desktopDownloadUrl =
      String.fromEnvironment('DESKTOP_DOWNLOAD_URL');

  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;

    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Informe e-mail e senha para continuar.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GetIt.I<AuthService>().login(_email.text.trim(), _password.text);
      if (mounted) context.go('/dashboard');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível entrar. Verifique suas credenciais.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadDesktop() async {
    final url = Uri.tryParse(_desktopDownloadUrl);
    if (url == null || url.scheme != 'https') return;
    try {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(() => _error = 'Não foi possível abrir o download do Windows.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível abrir o download do Windows.');
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _logo({double size = 54}) {
    return Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset(
        'assets/images/brilhart_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.business_outlined,
          color: AppColors.primary,
          size: 30,
        ),
      ),
    );
  }

  Widget _identity({bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _logo(size: 48),
        const SizedBox(width: 13),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Brilhart',
              style: TextStyle(
                fontSize: compact ? 19 : 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -.4,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'GESTÃO EMPRESARIAL',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _brandPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(52, 48, 52, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF101C2D),
        border: Border(right: BorderSide(color: AppColors.border)),
        borderRadius: BorderRadius.horizontal(left: Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _identity(),
          const Spacer(),
          const Text(
            'Tudo em ordem.\nTudo em um lugar.',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 37,
              height: 1.16,
              letterSpacing: -1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 19),
          const ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 410),
            child: Text(
              'Um ambiente de trabalho para organizar orçamentos, produção, clientes e resultados com clareza.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 40),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 23),
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ambiente exclusivo para a equipe Brilhart',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'BRILHART  /  SISTEMA DE GESTÃO',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _form({required bool compact}) {
    return AutofillGroup(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 396),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compact) ...[
              _identity(compact: true),
              const SizedBox(height: 44),
            ],
            const Text(
              'Bem-vindo de volta',
              style: TextStyle(
                fontSize: 28,
                letterSpacing: -.7,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Entre com seus dados para acessar o sistema.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 36),
            const Text('E-mail', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 9),
            TextField(
              key: const Key('login-email'),
              controller: _email,
              enabled: !_busy,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'seu@email.com',
                prefixIcon: Icon(Icons.alternate_email, size: 19),
              ),
            ),
            const SizedBox(height: 22),
            const Text('Senha', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 9),
            TextField(
              key: const Key('login-password'),
              controller: _password,
              enabled: !_busy,
              obscureText: _hidePassword,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Digite sua senha',
                prefixIcon: const Icon(Icons.lock_outline, size: 19),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: _busy ? null : () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(_hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.danger.withValues(alpha: .25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 17, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: FilledButton(
                key: const Key('login-submit'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Acessar sistema'),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 26),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 21),
            if (_desktopDownloadUrl.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _downloadDesktop,
                icon: const Icon(Icons.desktop_windows_outlined, size: 18),
                label: const Text('Baixar aplicativo Windows'),
              )
            else
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.desktop_windows_outlined, size: 16, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Aplicativo Windows em preparação',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            const Text(
              'Acesso restrito a usuários autorizados.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;
            final horizontalPadding = desktop ? 30.0 : 22.0;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: desktop ? 28 : 38,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: desktop
                      ? Container(
                          height: 660,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 11, child: _brandPanel()),
                              Expanded(
                                flex: 10,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: Center(child: _form(compact: false)),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(child: _form(compact: true)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

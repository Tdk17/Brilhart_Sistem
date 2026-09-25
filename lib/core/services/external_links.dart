import 'package:url_launcher/url_launcher.dart';

class ExternalLinks {
  const ExternalLinks._();

  static Future<bool> openWhatsApp(
    String rawPhone, {
    String message =
        'Olá! Aqui é da BrilhArte Laqueamentos. Estamos entrando em contato sobre seu atendimento.',
  }) async {
    var phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) return false;
    if (!phone.startsWith('55')) phone = '55$phone';

    final uri = Uri.https(
      'wa.me',
      '/$phone',
      {'text': message},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

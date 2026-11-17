import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp with a pre-filled message. The tap itself is tracked by the
/// caller so the funnel can be measured.
class WhatsAppService {
  const WhatsAppService();

  Future<bool> open({required String phone, required String message}) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final international = digits.startsWith('0')
        ? '234${digits.substring(1)}'
        : digits.startsWith('234')
            ? digits
            : '234$digits';
    final uri = Uri.parse(
      'https://wa.me/$international?text=${Uri.encodeComponent(message)}',
    );
    return launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}

final whatsAppServiceProvider = Provider<WhatsAppService>((ref) {
  return const WhatsAppService();
});

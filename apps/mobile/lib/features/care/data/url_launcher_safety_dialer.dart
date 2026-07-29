import 'package:url_launcher/url_launcher.dart';

import '../domain/safety_dialer.dart';

class UrlLauncherSafetyDialer implements SafetyDialer {
  const UrlLauncherSafetyDialer();

  @override
  Future<bool> call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}

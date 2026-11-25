import 'package:web/web.dart' as web;

String? readWebUserAgent() {
  try {
    final ua = web.window.navigator.userAgent.trim();
    return ua.isEmpty ? null : ua;
  } catch (_) {
    return null;
  }
}

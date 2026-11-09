import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String?> saveFinancialFile(
  String name,
  Uint8List bytes,
  String mimeType,
) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(link);
  link.click();
  link.remove();
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
  return name;
}

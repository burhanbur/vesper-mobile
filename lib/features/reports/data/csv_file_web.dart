import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String?> saveFinancialCsv(String name, String csv) async {
  final blob = web.Blob(
    [utf8.encode(csv).toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
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

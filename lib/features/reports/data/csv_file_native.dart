import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> saveFinancialCsv(String name, String csv) async {
  if (Platform.isAndroid) {
    return const MethodChannel('vesper/financial_export')
        .invokeMethod<String>('saveCsv', {'name': name, 'content': csv});
  }
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$name');
  await file.writeAsString(csv, flush: true);
  return file.path;
}

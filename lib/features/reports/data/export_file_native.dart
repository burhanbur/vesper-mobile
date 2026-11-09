import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> saveFinancialFile(
  String name,
  Uint8List bytes,
  String mimeType,
) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return const MethodChannel('vesper/financial_export').invokeMethod<String>(
      'saveFile',
      {'name': name, 'bytes': bytes, 'mimeType': mimeType},
    );
  }
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

import 'package:flutter/services.dart';
import 'package:sqlite3/wasm.dart';

Future<CommonSqlite3>? _sqlite;
Future<CommonSqlite3> exportSqlite() => _sqlite ??= _load();

Future<CommonSqlite3> _load() async {
  try {
    final data = await rootBundle.load('assets/sqlite3.wasm');
    return await WasmSqlite3.load(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } catch (_) {
    _sqlite = null;
    rethrow;
  }
}

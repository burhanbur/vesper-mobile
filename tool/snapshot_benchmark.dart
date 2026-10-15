// Run: flutter test tool/snapshot_benchmark.dart --reporter expanded
// Synthetic server-shaped histories only; never opens a real user's database.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store_native.dart';
import 'package:vesper_mobile/database/snapshot_cipher.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

void main() {
  test('file-backed snapshot storage benchmark', () {
    final directory = Directory.systemTemp.createTempSync('vesper-benchmark-');
    if (directory.parent.absolute.path != Directory.systemTemp.absolute.path ||
        !directory.path.contains('vesper-benchmark-')) {
      throw StateError('Unexpected benchmark directory');
    }
    addTearDown(() => directory.deleteSync(recursive: true));
    final results = <Map<String, dynamic>>[];
    for (final count in [1000, 10000, 50000]) {
      final snapshot = <String, dynamic>{
        'entities': {
          'transactions': {
            for (var index = 0; index < count; index++)
              'transaction-$index': {
                'id': 'transaction-$index',
                'user_id': 'benchmark',
                'account_id': 'cash',
                'category_id': 'food',
                'type': index % 5 == 0 ? 'INCOME' : 'EXPENSE',
                'amount': '${100 + index % 100000}.00',
                'currency': 'IDR',
                'version': '$index',
                'transacted_at': DateTime.utc(
                  2020,
                  1,
                  1,
                ).add(Duration(minutes: index * 15)).toIso8601String(),
                'description': 'Synthetic household purchase $index',
                'deleted_at': null,
              },
          },
        },
        'outbox': [
          for (var i = 0; i < 20; i++)
            {'id': 'original-$i', 'status': 'pending'},
        ],
        'cursor': '9007199254740993',
      };
      final bytes = utf8.encode(jsonEncode(snapshot)).length;
      for (final encrypted in [false, true]) {
        final path =
            '${directory.path}${Platform.pathSeparator}$count-$encrypted.sqlite';
        final store = LocalStore(
          sqlite3.open(path),
          cipher: encrypted
              ? SnapshotCipher(List.generate(32, (i) => i), 'benchmark')
              : null,
        );
        store.write(snapshot); // Warm up codecs/crypto and initial allocation.
        final repo = FinanceRepository(ApiClient(), store, 'benchmark');
        final write = <double>[], read = <double>[], atomic = <double>[];
        double measure(void Function() action) {
          final clock = Stopwatch()..start();
          action();
          return clock.elapsedMicroseconds / 1000;
        }

        for (var repeat = 0; repeat < 3; repeat++) {
          write.add(measure(() => store.write(snapshot)));
          read.add(
            measure(() {
              final restored = store.read();
              expect(
                (restored['entities'] as Map)['transactions'],
                hasLength(count),
              );
              expect(restored['cursor'], '9007199254740993');
              expect(restored['outbox'], snapshot['outbox']);
            }),
          );
          atomic.add(
            measure(
              () => repo.atomic(() {
                (repo.entities['transactions']['transaction-0']
                        as Map)['description'] =
                    'Updated synthetic purchase';
              }),
            ),
          );
        }
        double median(List<double> values) => (values..sort())[1];
        final row = {
          'rows': count,
          'encrypted': encrypted,
          'plaintext_bytes': bytes,
          'write_median_ms': median(write),
          'read_median_ms': median(read),
          'atomic_edit_median_ms': median(atomic),
          'database_bytes': File(path).lengthSync(),
        };
        results.add(row);
        stdout.writeln(jsonEncode(row));
        store.close();
      }
    }
    final output = File('build/benchmarks/snapshot-storage.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'workload':
            'synthetic server-shaped household history; 20 pending commands',
        'platform': Platform.operatingSystem,
        'dart': Platform.version,
        'mode': 'Flutter host test VM; file-backed SQLite WAL, synchronous FULL; median of 3 after warm-up',
        'results': results,
      }),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

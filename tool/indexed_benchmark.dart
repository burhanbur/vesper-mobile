// Run: flutter test --no-pub tool/indexed_benchmark.dart --reporter expanded
// Isolated synthetic data only; no existing account, filesystem path or API.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store_native.dart';
import 'package:vesper_mobile/database/transaction_query.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

void main() {
  test('indexed authenticated storage benchmark', () {
    final directory = Directory.systemTemp.createTempSync(
      'vesper-indexed-benchmark-',
    );
    if (directory.parent.absolute.path != Directory.systemTemp.absolute.path ||
        !directory.path.contains('vesper-indexed-benchmark-')) {
      throw StateError('Unexpected benchmark directory');
    }
    addTearDown(() => directory.deleteSync(recursive: true));
    final results = <Map<String, dynamic>>[];
    double measure(void Function() action) {
      final timer = Stopwatch()..start();
      action();
      return timer.elapsedMicroseconds / 1000;
    }

    double median(List<double> samples) =>
        (samples..sort())[samples.length ~/ 2];
    double p95(List<double> samples) =>
        (samples..sort())[(samples.length * .95).ceil() - 1];
    for (final count in [1000, 10000, 50000]) {
      final path = '${directory.path}${Platform.pathSeparator}$count.sqlite';
      final store = LocalStore.indexed(
        sqlite3.open(path),
        key: List.generate(32, (i) => i),
        userId: 'benchmark',
      );
      try {
        final initial = measure(
          () => store.write({
            'entities': {
              'accounts': {
                'cash': {'id': 'cash', 'balance': '9007199254740993.01'},
              },
              'transactions': {
                for (var i = 0; i < count; i++)
                  'tx-$i': {
                    'id': 'tx-$i',
                    'account_id': 'cash',
                    'category_id': 'food',
                    'type': i % 5 == 0 ? 'INCOME' : 'EXPENSE',
                    'amount': '${100 + i % 100000}.00',
                    'currency': 'IDR',
                    'version': '$i',
                    'deleted_at': null,
                    'transacted_at': DateTime.utc(2020)
                        .add(Duration(minutes: i * 15))
                        .toIso8601String(),
                    'description': 'Synthetic household purchase $i',
                  },
              },
            },
            'outbox': [
              for (var i = 0; i < 20; i++)
                {'id': 'original-$i', 'status': 'pending'},
            ],
            'cursor': '9007199254740993',
          }),
        );
        final repo = FinanceRepository(ApiClient(), store, 'benchmark');
        final start = DateTime.utc(2020), end = DateTime.utc(2020, 2);
        final summaryFirst = measure(
          () => store.transactionSummary(start, end),
        );
        void edit(int i) => repo.atomic(() {
          repo.entities['transactions']['tx-0']['description'] = 'Updated $i';
          repo.entities['accounts']['cash']['balance'] = '9007199254740993.01';
          repo.outbox[0]['attempts'] = i;
        });
        edit(0);
        store.transactionPage(const TransactionQuery());
        final saves = <double>[], pages = <double>[], summaries = <double>[];
        for (var i = 1; i <= 25; i++) {
          saves.add(measure(() => edit(i)));
          pages.add(
            measure(() => store.transactionPage(const TransactionQuery())),
          );
          summaries.add(measure(() => store.transactionSummary(start, end)));
        }
        final row = <String, dynamic>{
          'rows': count,
          'initial_import_ms': initial,
          'atomic_edit_median_ms': median(saves),
          'atomic_edit_p95_ms': p95(saves),
          'page100_median_ms': median(pages),
          'page100_p95_ms': p95(pages),
          'month_summary_first_ms': summaryFirst,
          'month_summary_cached_p95_ms': p95(summaries),
        };
        results.add(row);
        stdout.writeln(jsonEncode(row));
        expect(repo.outbox.length, 20);
        expect(repo.state['cursor'], '9007199254740993');
      } finally {
        store.close();
      }
    }
    final output = File('build/benchmarks/indexed-storage.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'platform': Platform.operatingSystem,
        'mode': 'Flutter host test VM; SQLite3MultipleCiphers ChaCha20-Poly1305; WAL/FULL; 25 warm samples',
        'results': results,
      }),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

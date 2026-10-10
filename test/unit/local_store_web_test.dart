@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:vesper_mobile/database/local_store.dart';

void main() {
  test('persists snapshots and isolates each user', () async {
    const firstId = 'storage-regression-first';
    const secondId = 'storage-regression-second';
    for (final id in [firstId, secondId]) {
      web.window.localStorage.removeItem('vesper-state-$id');
    }
    addTearDown(() {
      for (final id in [firstId, secondId]) {
        web.window.localStorage.removeItem('vesper-state-$id');
      }
    });
    final first = await LocalStore.open(firstId);
    final second = await LocalStore.open(secondId);
    final snapshot = {
      'entities': {'accounts': <dynamic>[]},
      'outbox': [
        {'id': 'mutation-1', 'status': 'pending'},
      ],
      'cursor': '42',
    };
    first.write(snapshot);
    first.close();
    expect((await LocalStore.open(firstId)).read(), snapshot);
    expect(second.read()['outbox'], isEmpty);
    expect(second.read()['cursor'], '0');
  });

  test('rejects invalid user identifiers', () async {
    await expectLater(LocalStore.open('../other-user'), throwsArgumentError);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/database/local_store.dart';

void main() {
  test('persists a complete snapshot including queued mutations', () {
    final store = LocalStore(sqlite3.openInMemory());
    addTearDown(store.close);
    expect(store.read()['outbox'], isEmpty);
    final snapshot = {
      'entities': {'accounts': <dynamic>[]},
      'outbox': [
        {'id': 'mutation-1', 'status': 'pending'},
      ],
      'cursor': '42',
    };
    store.write(snapshot);
    expect(store.read(), snapshot);
    store.write({...snapshot, 'cursor': '43'});
    expect(store.read()['cursor'], '43');
  });

  test('rejects invalid user identifiers before opening storage', () async {
    await expectLater(LocalStore.open('../other-user'), throwsArgumentError);
  });
}

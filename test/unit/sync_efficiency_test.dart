import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

class CountingSyncClient extends ApiClient {
  int pullCount = 0;
  int listCount = 0;
  final List<String> requestedListPaths = [];

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path == '/devices') {
      return body;
    }
    if (path == '/sync/pull') {
      pullCount++;
      return {'changes': [], 'next_version': '1', 'has_more': false};
    }
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    listCount++;
    requestedListPaths.add(path);
    if (path == '/account-types') {
      return [
        {'id': 'act-1', 'name': 'Bank Account', 'category': 'CASH'},
      ];
    }
    if (path == '/ref-account-types') {
      return [
        {'id': 'ref-1', 'name': 'BCA'},
      ];
    }
    if (path == '/ref-categories') {
      return [
        {'id': 'rc-1', 'name': 'Food'},
      ];
    }
    return [];
  }
}

void main() {
  testWidgets('requestDebouncedSync coalesces rapid mutations into a single sync call', (tester) async {
    final client = CountingSyncClient();
    final state = cachedFinanceState(client: client);
    await state.login(userId: 'user');

    final initialPulls = client.pullCount;

    // Simulate 3 rapid mutations
    state.requestDebouncedSync(const Duration(milliseconds: 300));
    state.requestDebouncedSync(const Duration(milliseconds: 300));
    state.requestDebouncedSync(const Duration(milliseconds: 300));

    // Advance 100ms - debounce should not have fired yet
    await tester.pump(const Duration(milliseconds: 100));
    expect(client.pullCount, initialPulls);

    // Advance 250ms more (total 350ms from last call) - debounce should fire exactly once
    await tester.pump(const Duration(milliseconds: 250));
    expect(client.pullCount, initialPulls + 1);

    state.dispose();
  });

  testWidgets('subsequent auto-sync skips already cached reference tables', (tester) async {
    final client = CountingSyncClient();
    final state = cachedFinanceState(client: client);
    await state.login(userId: 'user');

    // First login should load ref tables
    expect(client.requestedListPaths, contains('/ref-account-types'));
    expect(client.requestedListPaths, contains('/ref-categories'));

    client.requestedListPaths.clear();

    // Trigger auto sync
    state.requestAutomaticSync();
    await tester.pump();

    // Subsequent auto-sync should NOT re-request static ref tables
    expect(client.requestedListPaths, isNot(contains('/ref-account-types')));
    expect(client.requestedListPaths, isNot(contains('/ref-categories')));

    state.dispose();
  });
}


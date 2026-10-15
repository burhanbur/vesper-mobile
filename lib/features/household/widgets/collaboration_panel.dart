import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/network/api_client.dart';
import '../data/collaboration_repository.dart';

/// No durable cross-member cache: revocation is checked on every online refresh.
class CollaborationPanel extends StatefulWidget {
  const CollaborationPanel({super.key});
  @override
  State<CollaborationPanel> createState() => _CollaborationPanelState();
}

class _CollaborationPanelState extends State<CollaborationPanel>
    with WidgetsBindingObserver {
  String? _scope;
  int _token = 0, _contributionPage = 1, _feedPage = 1, _memberPage = 1;
  bool _owner = false;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state != AppLifecycleState.resumed) {
      setState(() {
        ++_token;
        _data = null;
        _members = [];
        _owner = false;
        _loading = false;
        _error = null;
      });
    } else {
      final app = AppStateScope.of(context);
      if (app.repository != null &&
          !app.isOfflineMode &&
          app.activeHouseholdId.isNotEmpty) {
        _load();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final scope =
        '${state.repository?.userId}:${state.activeHouseholdId}:${state.householdReportPeriod}:${state.isOfflineMode}';
    if (_scope != scope) {
      _scope = scope;
      _token++;
      _data = null;
      _members = [];
      _error = null;
      _loading = false;
      _owner = false;
      _contributionPage = _feedPage = _memberPage = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scope == scope) _load();
      });
    }
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    final repo = state.repository;
    final group = state.activeHouseholdId;
    final period = state.householdReportPeriod;
    final contributionPage = _contributionPage;
    final feedPage = _feedPage;
    final memberPage = _memberPage;
    final token = ++_token;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
      _members = [];
      _owner = false;
    });
    try {
      if (repo == null || state.isOfflineMode) {
        throw StateError('Koneksi online diperlukan.');
      }
      final service = CollaborationRepository(repo.client);
      final data = await service.read(group, period, contributionPage);
      if (!mounted || token != _token) return;
      final feedData = feedPage == contributionPage
          ? data
          : await service.read(group, period, feedPage);
      if (!mounted || token != _token) return;
      final members = await service.members(group, memberPage);
      if (!mounted || token != _token) return;
      final role = await service.actorRole(group, repo.userId);
      if (!mounted || token != _token) return;
      if (role == null) {
        throw const ApiFailure(
          'Keanggotaan tidak dapat diverifikasi. Muat ulang grup.',
          statusCode: 403,
        );
      }
      setState(() {
        _data = {...data, 'feed': feedData['feed']};
        _members = members;
        _owner = role == 'OWNER';
      });
    } catch (error) {
      if (mounted && token == _token) {
        setState(() {
          _error = '$error';
        });
      }
    } finally {
      if (mounted && token == _token) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _manage(String user, String action) async {
    final state = AppStateScope.of(context);
    final repo = state.repository;
    final group = state.activeHouseholdId;
    final scope = _scope;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'REMOVE' ? 'Hapus keanggotaan?' : 'Alihkan kepemilikan?',
        ),
        content: Text(
          action == 'REMOVE'
              ? 'Akses grup serta pembagian akun dan pemetaan kategori anggota akan dicabut. Data pribadi tidak dihapus. Bergabung kembali memerlukan undangan.'
              : 'Anda akan menjadi anggota biasa. Pemilik baru dapat mengelola anggota dan kategori grup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        _loading ||
        repo == null ||
        scope != _scope ||
        state.isOfflineMode ||
        !identical(repo, state.repository)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CollaborationRepository(repo.client).manage(group, user, action);
      if (!mounted || scope != _scope) return;
      // Remove privileged presentation immediately; the containing group list is refreshed separately.
      setState(() {
        _data = null;
        _members = [];
      });
      await state.refresh();
      if (!mounted || scope != _scope || !identical(repo, state.repository)) {
        return;
      }
      await _load();
    } catch (error) {
      if (mounted && scope == _scope) {
        setState(() {
          _error = '$error';
          _loading = false;
          _data = null;
          _members = [];
          _owner = false;
        });
      }
    }
  }

  Widget _pagination(
    String label,
    int page,
    int count,
    ValueChanged<int> select,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: _loading || page == 1
              ? null
              : () {
                  select(page - 1);
                  _load();
                },
          child: Text('$label sebelumnya'),
        ),
        Text('$label • Halaman $page'),
        TextButton(
          onPressed: _loading || count < 20
              ? null
              : () {
                  select(page + 1);
                  _load();
                },
          child: Text('$label berikutnya'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final owner = _owner;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kolaborasi grup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Online saja • Saldo akun CASH yang dibagikan, per mata uang. Kontribusi = pemasukan/pengeluaran berkategori terpetakan pada bulan UTC terpilih, bukan utang atau setoran anggota. Transfer dan investasi tidak dihitung.',
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(
              onPressed: _loading || state.isOfflineMode ? null : _load,
              child: const Text('Muat ulang kolaborasi'),
            ),
            if (_data != null) ...[
              const Text('Saldo kas bersama'),
              if ((_data!['balances'] as List).isEmpty)
                const Text('Tidak ada saldo kas dibagikan.'),
              for (final row in _data!['balances'] as List)
                Text('${row['currency']} ${row['balance']}'),
              const Divider(),
              const Text('Kontribusi bulanan (halaman ini)'),
              for (final row in _data!['contributions'] as List)
                Text(
                  '${row['user_id']} • ${row['currency']} • Masuk ${row['income']} • Keluar ${row['expense']}',
                ),
              _pagination(
                'Kontribusi',
                _contributionPage,
                (_data!['contributions'] as List).length,
                (page) => _contributionPage = page,
              ),
              const Divider(),
              const Text('Aktivitas bulanan (tanpa catatan/akun pribadi)'),
              for (final row in _data!['feed'] as List)
                Text(
                  '${row['transacted_at']} • ${row['category']} • ${row['type']} ${row['currency']} ${row['amount']}',
                ),
              _pagination(
                'Aktivitas',
                _feedPage,
                (_data!['feed'] as List).length,
                (page) => _feedPage = page,
              ),
              const Divider(),
              const Text('Anggota (halaman ini)'),
              for (final member in _members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${member['name']} • ${member['role']}'),
                  trailing: member['role'] == 'OWNER'
                      ? null
                      : PopupMenuButton<String>(
                          enabled:
                              !_loading &&
                              !state.isOfflineMode &&
                              (owner ||
                                  member['user_id'] ==
                                      state.repository?.userId),
                          onSelected: (action) =>
                              _manage(member['user_id'] as String, action),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'REMOVE',
                              child: Text('Hapus / keluar'),
                            ),
                            if (owner)
                              const PopupMenuItem(
                                value: 'TRANSFER_OWNER',
                                child: Text('Jadikan pemilik'),
                              ),
                          ],
                        ),
                ),
              const Text(
                'Pemilik harus mengalihkan kepemilikan sebelum keluar. Setiap daftar memiliki halaman sendiri; saldo tetap mencakup seluruh akun kas yang dibagikan.',
              ),
              _pagination(
                'Anggota',
                _memberPage,
                _members.length,
                (page) => _memberPage = page,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

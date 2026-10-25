import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import 'group_list_status.dart';

class GroupAccountSharingSheet extends StatefulWidget {
  final String groupId;
  const GroupAccountSharingSheet({super.key, required this.groupId});
  @override
  State<GroupAccountSharingSheet> createState() =>
      _GroupAccountSharingSheetState();
}

class _GroupAccountSharingSheetState extends State<GroupAccountSharingSheet> {
  String? _selected, _error;
  bool _busy = false;
  AppState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    if (identical(_state, state)) return;
    _state = state;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_state, state)) {
        state.loadGroupList(widget.groupId);
      }
    });
  }

  Future<void> _submit(bool remove) async {
    if (_busy || _selected == null) return;
    final accountId = _selected!;
    final state = AppStateScope.of(context);
    final repo = state.repository;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          remove ? 'Hentikan pembagian akun?' : 'Bagikan akun ke grup?',
        ),
        content: Text(
          remove
              ? 'Akun ini tidak lagi berkontribusi ke laporan grup. Riwayat pribadi tidak dihapus.'
              : 'Transaksi akun ini dapat berkontribusi ke laporan grup melalui pemetaan kategori, termasuk riwayat sebelumnya. Anggota grup dapat melihat agregat tersebut. Saldo dan transaksi pribadi tidak diubah.',
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
        _busy ||
        !identical(state.repository, repo) ||
        widget.groupId != state.activeHouseholdId) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.shareGroupAccount(
        groupId: widget.groupId,
        accountId: accountId,
        remove: remove,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final repo = state.repository;
    final accounts = (repo?.rows('accounts') ?? <Map<String, dynamic>>[])
        .where(
          (row) => row['user_id'] == repo?.userId && row['deleted_at'] == null,
        )
        .toList();
    final validSelection = accounts.any((row) => row['id'] == _selected);
    final rows = state.groupListRows(widget.groupId);
    final shared = rows.any((row) => row['account_id'] == _selected);
    final available =
        !_busy &&
        !state.isOfflineMode &&
        widget.groupId == state.activeHouseholdId &&
        state.groupListFresh(widget.groupId) &&
        !state.groupListLoading(widget.groupId);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Pembagian Akun Grup (online)'),
            GroupListStatus(state: state, groupId: widget.groupId),
            for (final row in rows) Text('Dibagikan oleh Anda: ${row['name']}'),
            if (state.groupListFresh(widget.groupId) && rows.isEmpty)
              const Text('Belum ada akun Anda yang dibagikan.'),
            if (_selected != null)
              Text(
                shared
                    ? 'Akun terpilih tercatat dibagikan oleh Anda.'
                    : 'Akun terpilih tidak tercatat pada daftar ini.',
              ),
            if (accounts.isEmpty)
              const Text('Tidak ada akun pribadi yang tersedia.')
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Akun pribadi'),
                items: accounts
                    .where((row) => row['id'] != null && row['name'] != null)
                    .map(
                      (row) => DropdownMenuItem(
                        value: row['id'].toString(),
                        child: Text(
                          row['name'].toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _selected = value),
              ),
            if (_error != null) Text(_error!),
            FilledButton(
              onPressed: available && validSelection && !shared
                  ? () => _submit(false)
                  : null,
              child: Text(_busy ? 'Memproses…' : 'Bagikan akun'),
            ),
            TextButton(
              onPressed: available && validSelection && shared
                  ? () => _submit(true)
                  : null,
              child: const Text('Hentikan pembagian akun terpilih'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import 'group_list_status.dart';

class GroupCategoryMappingSheet extends StatefulWidget {
  final String groupId, categoryId, categoryName, categoryType;
  const GroupCategoryMappingSheet({
    super.key,
    required this.groupId,
    required this.categoryId,
    required this.categoryName,
    required this.categoryType,
  });
  @override
  State<GroupCategoryMappingSheet> createState() =>
      _GroupCategoryMappingSheetState();
}

class _GroupCategoryMappingSheetState extends State<GroupCategoryMappingSheet> {
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
        state.loadGroupList(widget.groupId, mappings: true);
      }
    });
  }

  Future<void> _submit(bool remove) async {
    if (_busy || _selected == null) return;
    final state = AppStateScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.mapGroupCategory(
        groupId: widget.groupId,
        groupCategoryId: widget.categoryId,
        personalCategoryId: _selected!,
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
    final categories = (repo?.rows('categories') ?? <Map<String, dynamic>>[])
        .where(
          (row) =>
              row['user_id'] == repo?.userId &&
              row['type'] == widget.categoryType &&
              row['deleted_at'] == null,
        )
        .toList();
    final rows = state.groupListRows(widget.groupId, mappings: true);
    final mapped = rows.any(
      (row) =>
          row['group_category_id'] == widget.categoryId &&
          row['user_category_id'] == _selected,
    );
    final valid = categories.any((row) => row['id'] == _selected);
    final available =
        !_busy &&
        !state.isOfflineMode &&
        widget.groupId == state.activeHouseholdId &&
        state.groupListFresh(widget.groupId, mappings: true) &&
        !state.groupListLoading(widget.groupId, mappings: true);
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
            Text('Pemetaan: ${widget.categoryName}'),
            const Text(
              'Membutuhkan koneksi. Hanya transaksi akun yang dibagikan yang masuk laporan grup. Riwayat pribadi tidak diubah.',
            ),
            GroupListStatus(
              state: state,
              groupId: widget.groupId,
              mappings: true,
            ),
            for (final row in rows.where(
              (row) => row['group_category_id'] == widget.categoryId,
            ))
              Text(
                'Dipetakan oleh Anda: ${categories.where((category) => category['id'] == row['user_category_id']).firstOrNull?['name'] ?? row['user_category_id']}',
              ),
            if (state.groupListFresh(widget.groupId, mappings: true) &&
                !rows.any(
                  (row) => row['group_category_id'] == widget.categoryId,
                ))
              const Text('Belum ada pemetaan Anda ke kategori grup ini.'),
            if (_selected != null)
              Text(
                mapped
                    ? 'Pasangan terpilih tercatat dipetakan oleh Anda.'
                    : 'Pasangan terpilih tidak tercatat pada daftar ini.',
              ),
            if (categories.isEmpty)
              const Text('Tidak ada kategori pribadi dengan tipe yang sama.')
            else
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Kategori pribadi',
                ),
                items: categories
                    .where((row) => row['id'] != null && row['name'] != null)
                    .map(
                      (row) => DropdownMenuItem<String>(
                        value: row['id'].toString(),
                        child: Text(row['name'].toString()),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _selected = value),
              ),
            if (_error != null) Text(_error!),
            FilledButton(
              onPressed: available && valid && !mapped
                  ? () => _submit(false)
                  : null,
              child: Text(_busy ? 'Memproses…' : 'Hubungkan kategori'),
            ),
            TextButton(
              onPressed: available && valid && mapped
                  ? () => _submit(true)
                  : null,
              child: const Text('Lepas pasangan kategori terpilih'),
            ),
          ],
        ),
      ),
    );
  }
}

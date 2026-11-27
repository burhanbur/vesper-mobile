import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
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
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pemetaan: ${widget.categoryName}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Membutuhkan koneksi. Hanya transaksi akun yang dibagikan yang masuk laporan grup.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              GroupListStatus(
                state: state,
                groupId: widget.groupId,
                mappings: true,
              ),
              for (final row in rows.where(
                (row) => row['group_category_id'] == widget.categoryId,
              ))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Dipetakan oleh Anda: ${categories.where((category) => category['id'] == row['user_category_id']).firstOrNull?['name'] ?? row['user_category_id']}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.income,
                    ),
                  ),
                ),
              if (state.groupListFresh(widget.groupId, mappings: true) &&
                  !rows.any(
                    (row) => row['group_category_id'] == widget.categoryId,
                  ))
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Belum ada pemetaan Anda ke kategori grup ini.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              if (_selected != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    mapped
                        ? 'Pasangan terpilih tercatat dipetakan oleh Anda.'
                        : 'Pasangan terpilih tidak tercatat pada daftar ini.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              if (categories.isEmpty)
                const Text(
                  'Tidak ada kategori pribadi dengan tipe yang sama.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                )
              else
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Kategori pribadi',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.expense,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: available && valid && !mapped
                    ? () => _submit(false)
                    : null,
                child: Text(_busy ? 'Memproses…' : 'Hubungkan kategori'),
              ),
              const SizedBox(height: 6),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                onPressed: available && valid && mapped
                    ? () => _submit(true)
                    : null,
                child: const Text('Lepas pasangan kategori terpilih'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

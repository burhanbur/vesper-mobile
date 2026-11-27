import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/string_formatter.dart';

class CreateGroupCategorySheet extends StatefulWidget {
  final String? categoryId, groupId;
  final String initialName, initialType;
  const CreateGroupCategorySheet({
    super.key,
    this.categoryId,
    this.groupId,
    this.initialName = '',
    this.initialType = 'EXPENSE',
  });

  @override
  State<CreateGroupCategorySheet> createState() =>
      _CreateGroupCategorySheetState();
}

class _CreateGroupCategorySheetState extends State<CreateGroupCategorySheet> {
  final _name = TextEditingController();
  String _type = 'EXPENSE';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName;
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final state = AppStateScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final formattedName = StringFormatter.capitalizeWords(_name.text);
      if (widget.categoryId != null) {
        await state.updateGroupCategory(
          categoryId: widget.categoryId!,
          groupId: widget.groupId ?? '',
          name: formattedName,
          type: _type,
        );
      } else {
        await state.createGroupCategory(name: formattedName, type: _type);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus kategori grup?'),
        content: Text(
          'Kategori "${widget.initialName}" dan seluruh pemetaannya dalam grup akan dihapus. '
          'Laporan grup dapat berubah. Kategori dan riwayat transaksi pribadi tidak dihapus. '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, hapus kategori grup'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _saving) return;
    final state = AppStateScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await state.deleteGroupCategory(
        groupId: widget.groupId ?? '',
        categoryId: widget.categoryId!,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
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
                    widget.categoryId == null
                        ? 'Tambah Kategori Grup'
                        : 'Edit Kategori Grup',
                    style: const TextStyle(
                      fontSize: 18,
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
              'Membutuhkan koneksi. Tidak mengubah kategori atau transaksi pribadi.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (widget.categoryId != null) ...[
              const SizedBox(height: 4),
              const Text(
                'Tipe tidak dapat diubah jika kategori sudah dipetakan.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: !_saving,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              inputFormatters: const [CapitalizeWordsInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Nama kategori grup',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: 'Tipe kategori',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'EXPENSE', child: Text('Pengeluaran')),
                DropdownMenuItem(value: 'INCOME', child: Text('Pemasukan')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value!),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.expense,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Menyimpan…' : 'Simpan kategori grup'),
            ),
            if (widget.categoryId != null &&
                AppStateScope.of(context).canManageGroupCategories) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                onPressed: _saving || AppStateScope.of(context).isOfflineMode
                    ? null
                    : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus kategori grup'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

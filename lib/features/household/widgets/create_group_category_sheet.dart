import 'package:flutter/material.dart';

import '../../../app/app_state.dart';

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
      if (widget.categoryId != null) {
        await state.updateGroupCategory(
          categoryId: widget.categoryId!,
          groupId: widget.groupId ?? '',
          name: _name.text,
          type: _type,
        );
      } else {
        await state.createGroupCategory(name: _name.text, type: _type);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
  Widget build(BuildContext context) => Padding(
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
          Text(
            widget.categoryId == null
                ? 'Tambah Kategori Grup'
                : 'Edit Kategori Grup',
          ),
          const Text(
            'Membutuhkan koneksi. Tidak mengubah kategori atau transaksi pribadi.',
          ),
          if (widget.categoryId != null)
            const Text(
              'Tipe tidak dapat diubah jika kategori sudah dipetakan.',
            ),
          TextField(
            controller: _name,
            enabled: !_saving,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Nama kategori grup'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipe kategori'),
            items: const [
              DropdownMenuItem(value: 'EXPENSE', child: Text('Pengeluaran')),
              DropdownMenuItem(value: 'INCOME', child: Text('Pemasukan')),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _type = value!),
          ),
          if (_error != null) Text(_error!),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan…' : 'Simpan kategori grup'),
          ),
          if (widget.categoryId != null &&
              AppStateScope.of(context).canManageGroupCategories)
            TextButton.icon(
              onPressed: _saving || AppStateScope.of(context).isOfflineMode
                  ? null
                  : _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus kategori grup'),
            ),
        ],
      ),
    ),
  );
}

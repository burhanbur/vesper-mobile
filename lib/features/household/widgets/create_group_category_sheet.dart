import 'package:flutter/material.dart';

import '../../../app/app_state.dart';

class CreateGroupCategorySheet extends StatefulWidget {
  const CreateGroupCategorySheet({super.key});

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
      await state.createGroupCategory(name: _name.text, type: _type);
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
          const Text('Tambah Kategori Grup'),
          const Text(
            'Membutuhkan koneksi. Tidak mengubah kategori atau transaksi pribadi.',
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
        ],
      ),
    ),
  );
}

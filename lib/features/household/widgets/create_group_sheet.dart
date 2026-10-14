import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../models/household.dart';

class CreateOrJoinGroupSheet extends StatefulWidget {
  final int initialTabIndex;

  const CreateOrJoinGroupSheet({super.key, this.initialTabIndex = 0});

  static Future<void> show(BuildContext context, {int initialTabIndex = 0}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          CreateOrJoinGroupSheet(initialTabIndex: initialTabIndex),
    );
  }

  @override
  State<CreateOrJoinGroupSheet> createState() => _CreateOrJoinGroupSheetState();
}

class _CreateOrJoinGroupSheetState extends State<CreateOrJoinGroupSheet> {
  late int _activeTab;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _codeController = TextEditingController();
  final _groupIdController = TextEditingController();
  bool _joining = false;
  GroupType _selectedType = GroupType.roommates;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _codeController.dispose();
    _groupIdController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate(AppState state) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan nama grup terlebih dahulu'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await state.createHousehold(
        name: name,
        type: _selectedType,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Grup "$name" berhasil dibuat & diaktifkan!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  Future<void> _handleJoin(AppState state) async {
    if (_joining) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan kode undangan grup'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _joining = true);
    try {
      await state.joinHousehold(groupId: _groupIdController.text, code: code);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    } finally {
      if (mounted) setState(() => _joining = false);
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil bergabung ke grup dengan kode $code!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Tab Selector: Buat Grup vs Gabung via Kode
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeTab == 0
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _activeTab == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '+ Buat Grup Baru',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _activeTab == 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _activeTab == 0
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeTab == 1
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _activeTab == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '🔑 Gabung via Kode',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _activeTab == 1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _activeTab == 1
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_activeTab == 0) ...[
              // FORM: BUAT GRUP
              const Text(
                'Nama Grup Finansial',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Misal: Kosan Senopati, Trip Bali, Kas Usaha',
                  prefixIcon: const Icon(
                    Icons.groups_rounded,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Tipe Grup',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GroupType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return InkWell(
                    onTap: () => setState(() => _selectedType = type),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryLight.withValues(alpha: 0.15)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            type.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            type.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              const Text(
                'Deskripsi / Catatan (Opsional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText:
                      'Misal: Patungan sewa, listrik, dan kas darurat bulanan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _handleCreate(state),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Buat & Aktifkan Grup',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              // The server requires both group identity and invitation code.
              TextField(
                controller: _groupIdController,
                decoration: const InputDecoration(labelText: 'ID Grup (UUID)'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kode Undangan Grup',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: '12 karakter, contoh: ABCD1234EFGH',
                  prefixIcon: const Icon(
                    Icons.vpn_key_rounded,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Minta pengelola atau pembuat grup untuk membagikan kode undangan yang tertera di halaman detail grup.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _joining ? null : () => _handleJoin(state),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Gabung ke Grup Sekarang',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

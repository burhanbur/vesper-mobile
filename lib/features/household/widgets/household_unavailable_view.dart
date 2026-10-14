import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_state.dart';
import 'create_group_sheet.dart';
import 'create_group_category_sheet.dart';
import 'group_switcher_sheet.dart';

/// Category snapshots are supported; balance and contribution totals are not.
class HouseholdUnavailableView extends StatefulWidget {
  const HouseholdUnavailableView({super.key});

  @override
  State<HouseholdUnavailableView> createState() =>
      _HouseholdUnavailableViewState();
}

class _HouseholdUnavailableViewState extends State<HouseholdUnavailableView> {
  AppState? _state;
  String? _groupKey;

  void _changeMonth(AppState state, int delta) {
    final parts = state.householdReportPeriod.split('-');
    final date = DateTime.utc(int.parse(parts[0]), int.parse(parts[1]) + delta);
    if (date.year < 1000 || date.year > 9999) return;
    state.loadHouseholdCategoryReport(
      period:
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final key = '${state.repository?.userId}:${state.activeHouseholdId}';
    if (!identical(state, _state) || key != _groupKey) {
      _state = state;
      _groupKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_state, state) && key == _groupKey) {
          state.loadHouseholdCategoryReport();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final group = state.activeHousehold;
    final hasGroup = state.households.isNotEmpty;
    final membersLoaded =
        state.repository?.entities.containsKey('members:${group.id}') == true;
    final categoriesLoaded =
        state.repository?.entities.containsKey(
          'group_categories:${group.id}',
        ) ==
        true;
    return Scaffold(
      appBar: AppBar(
        title: Text(hasGroup ? group.name : 'Grup Finansial'),
        actions: [
          if (hasGroup)
            IconButton(
              tooltip: 'Ganti Grup',
              onPressed: () => GroupSwitcherSheet.show(context),
              icon: const Icon(Icons.swap_horiz),
            ),
          IconButton(
            tooltip: 'Buat / Gabung Grup',
            onPressed: () => CreateOrJoinGroupSheet.show(context),
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!hasGroup)
            const Text(
              'Belum ada grup tersimpan di perangkat. Muat ulang saat terhubung untuk memeriksa keanggotaan.',
            )
          else ...[
            const ListTile(
              title: Text('Saldo Kas Bersama'),
              subtitle: Text(
                'Belum tersedia. Saldo akun grup belum terintegrasi; ini bukan saldo nol.',
              ),
            ),
            const ListTile(
              title: Text('Kontribusi & Riwayat Transaksi Grup'),
              subtitle: Text(
                'Belum tersedia. Transaksi pribadi tidak dianggap sebagai transaksi grup.',
              ),
            ),
            const ListTile(
              title: Text('Pencatatan & Pengelolaan Grup'),
              subtitle: Text(
                'Pencatatan kas grup, perubahan informasi, dan pengelolaan anggota belum tersedia di aplikasi ini.',
              ),
            ),
            const Divider(),
            const Text('ID Grup'),
            SelectableText(group.id),
            const SizedBox(height: 12),
            const Text('Kode Undangan Grup'),
            SelectableText(
              group.inviteCode.isEmpty
                  ? 'Kode belum tersedia di perangkat.'
                  : group.inviteCode,
              key: const ValueKey('household_invite_code'),
            ),
            TextButton.icon(
              onPressed: group.inviteCode.isEmpty
                  ? null
                  : () async {
                      try {
                        await Clipboard.setData(
                          ClipboardData(text: group.inviteCode),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kode undangan disalin.'),
                          ),
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Kode tidak dapat disalin. Silakan salin secara manual.',
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.copy),
              label: const Text('Salin kode'),
            ),
            const Text(
              'Bagikan ID grup dan kode undangan. Menambahkan anggota langsung belum didukung.',
            ),
            const Divider(),
            Text(
              membersLoaded
                  ? '${group.members.length} anggota tersimpan'
                  : 'Daftar anggota belum tersedia di perangkat.',
            ),
            for (final member in group.members)
              ListTile(
                title: Text(member.name),
                subtitle: Text(member.roleName),
              ),
            const Divider(),
            const Text('Laporan Kategori Grup — Bulan UTC'),
            Row(
              children: [
                IconButton(
                  tooltip: 'Bulan UTC sebelumnya',
                  onPressed: () => _changeMonth(state, -1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${state.householdReportPeriod} (UTC)',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Bulan UTC berikutnya',
                  onPressed: () => _changeMonth(state, 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const Text(
              'Agregat server untuk akun yang dibagikan dalam grup ini; bukan transaksi pribadi perangkat.',
            ),
            if (state.householdReportLoading) const LinearProgressIndicator(),
            if (state.householdCategoryReport case final report?) ...[
              Text(
                'Cache lokal • Diambil: ${report.fetchedAt.toUtc().toIso8601String()} (UTC)',
              ),
              if (report.categories.isEmpty)
                const Text(
                  'Laporan server tidak memiliki kategori untuk periode ini.',
                ),
              for (final category in report.categories)
                ListTile(
                  title: Text(category.name),
                  subtitle: Text(
                    category.type == 'INCOME' ? 'Pemasukan' : 'Pengeluaran',
                  ),
                  trailing: Text(
                    state.isBalanceHidden
                        ? 'Rp •••••'
                        : 'Rp ${category.type == 'INCOME' ? category.income : category.expense}',
                  ),
                ),
            ] else
              const Text(
                'Agregat belum tersedia untuk bulan ini; bukan nominal nol.',
              ),
            if (state.householdReportError != null)
              Text('Laporan gagal dimuat: ${state.householdReportError}'),
            TextButton(
              onPressed: state.householdReportLoading || state.isOfflineMode
                  ? null
                  : () => state.loadHouseholdCategoryReport(),
              child: const Text('Muat ulang laporan kategori'),
            ),
            const Divider(),
            const Text('Kategori Grup'),
            if (state.canManageGroupCategories)
              TextButton.icon(
                onPressed: state.isOfflineMode
                    ? null
                    : () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => AppStateScope(
                          state: state,
                          child: const CreateGroupCategorySheet(),
                        ),
                      ),
                icon: const Icon(Icons.add),
                label: const Text('Tambah kategori grup (online)'),
              ),
            if (!categoriesLoaded)
              const Text('Daftar kategori belum tersedia di perangkat.')
            else if (state.groupCategories.isEmpty)
              const Text('Tidak ada kategori pada data grup tersimpan.')
            else ...[
              for (final category in state.groupCategories)
                ListTile(
                  title: Text(category.name),
                  subtitle: const Text(
                    'Daftar kategori tersimpan; nominal ada pada laporan bulan UTC di atas.',
                  ),
                ),
            ],
          ],
          if (state.isOfflineMode)
            const Text('Mode offline: menampilkan data grup tersimpan.'),
          if (state.dataError != null) Text(state.dataError!),
          TextButton(
            onPressed: state.loading || state.isOfflineMode
                ? null
                : state.refresh,
            child: const Text('Muat ulang data grup'),
          ),
        ],
      ),
    );
  }
}

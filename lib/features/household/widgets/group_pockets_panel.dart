import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/group_pocket_repository.dart';
import '../state/group_pocket_state.dart';

class GroupPocketsPanel extends StatefulWidget {
  final AppState app;
  final String groupId;
  const GroupPocketsPanel({
    super.key,
    required this.app,
    required this.groupId,
  });
  @override
  State<GroupPocketsPanel> createState() => _GroupPocketsPanelState();
}

class _GroupPocketsPanelState extends State<GroupPocketsPanel>
    with WidgetsBindingObserver {
  late final GroupPocketState state;
  @override
  void initState() {
    super.initState();
    state = GroupPocketState(widget.app, widget.groupId);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) state.load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) =>
      state.suspend(value != AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    super.dispose();
  }

  String money(String value, String currency) => widget.app.isBalanceHidden
      ? '••••••'
      : CurrencyFormatter.formatCurrency(value, currency: currency);

  Future<void> sheet(Widget child) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => child,
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Kantong tujuan grup',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        _Badge(
                          text: 'TRANSPARAN',
                          color: AppColors.income,
                          bg: AppColors.incomeLight,
                        ),
                      ],
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Wadah bersama untuk alokasi rekening anggota',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang kantong',
                visualDensity: VisualDensity.compact,
                onPressed: state.available && !state.loading && !state.busy
                    ? state.load
                    : null,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seluruh saldo akun ditautkan, bukan dipindahkan atau dicadangkan (bukan saldo nol). Semua anggota aktif dapat membuat kantong.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!state.available)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Koneksi online dan keanggotaan aktif diperlukan.',
                style: TextStyle(fontSize: 11.5, color: AppColors.warning),
              ),
            ),
          if (state.loading || state.busy)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(minHeight: 2.5),
            ),
          if (state.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.expenseLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.error!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.expense,
                ),
              ),
            ),
          if (state.fresh && state.pockets.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.accentLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.savings_outlined,
                      size: 28,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Belum ada kantong tujuan (bukan saldo nol).',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Contoh: Belanja Bulanan, Dana Darurat, Tabungan Liburan bersama pasangan.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final pocket in state.pockets)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: state.canWrite
                    ? () => sheet(
                        _PocketDetails(state: state, pocketId: pocket.id),
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.savings_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pocket.name,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (pocket.description?.isNotEmpty == true)
                                  Text(
                                    pocket.description!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: pocket.accounts.isNotEmpty
                                  ? AppColors.incomeLight
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${pocket.accounts.length} akun',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: pocket.accounts.isNotEmpty
                                    ? AppColors.income
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      const Divider(height: 18, color: AppColors.divider),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Saldo Kantong',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (pocket.balances.isEmpty)
                                const Text(
                                  'Belum ada akun tertaut',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              else
                                for (final balance in pocket.balances)
                                  Text(
                                    money(balance.balance, balance.currency),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                            ],
                          ),
                          const Text(
                            'Lihat rincian →',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentDark,
                            ),
                          ),
                        ],
                      ),
                      if (pocket.accounts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final acc in pocket.accounts)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.border.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${acc.ownerName.split(' ').first}: ${acc.name}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: state.canWrite
                  ? () => sheet(_CreatePocket(state: state))
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Buat kantong',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;

  const _Badge({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// A pinned header/footer surrounds the independently scrollable sheet body.
class _PocketSheet extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget actions;
  final String? subtitle;
  final List<Widget>? headerActions;

  const _PocketSheet({
    required this.title,
    required this.body,
    required this.actions,
    this.subtitle,
    this.headerActions,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ...?headerActions,
                      IconButton(
                        tooltip: 'Tutup',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.textMuted,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: body,
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
              ),
              child: actions,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CreatePocket extends StatefulWidget {
  final GroupPocketState state;
  const _CreatePocket({required this.state});
  @override
  State<_CreatePocket> createState() => _CreatePocketState();
}

class _CreatePocketState extends State<_CreatePocket> {
  final name = TextEditingController(), description = TextEditingController();
  final form = GlobalKey<FormState>();

  final suggestions = const [
    ('🛒 Belanja Rumah', 'Belanja Bulanan & Kebutuhan Dapur'),
    ('🛡️ Dana Darurat', 'Cadangan Tak Terduga'),
    ('🏖️ Liburan', 'Tabungan Jalan-jalan Bersama'),
    ('👶 Anak', 'Kebutuhan & Pendidikan Anak'),
    ('💡 Tagihan', 'Listrik, Air, Internet & Langganan'),
    ('🏠 Rumah', 'Cicilan & Perawatan Rumah'),
  ];

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) => _PocketSheet(
      title: 'Buat kantong tujuan',
      subtitle: 'Kantong alokasi dana bersama pasangan / anggota',
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Cepat atau Ketik Nama:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in suggestions)
                  ActionChip(
                    label: Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppColors.surfaceVariant.withValues(
                      alpha: 0.8,
                    ),
                    side: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.7),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onPressed: () {
                      setState(() {
                        name.text = item.$1.replaceAll(
                          RegExp(r'^[^\w\s]+\s*'),
                          '',
                        );
                        description.text = item.$2;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: 'Nama kantong',
                hintText: 'Contoh: Belanja Bulanan',
                prefixIcon: const Icon(Icons.savings_outlined, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: description,
              maxLength: 2000,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Deskripsi (opsional)',
                hintText: 'Tujuan penggunaan dana ini...',
                prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if (widget.state.error != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.expenseLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.state.error!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.expense,
                  ),
                ),
              ),
            if (!widget.state.available)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Sesi atau koneksi berubah. Tutup dan muat ulang.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.warning),
                ),
              ),
          ],
        ),
      ),
      actions: SizedBox(
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: !widget.state.canWrite
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  final ok = await widget.state.create(
                    name.text,
                    description.text,
                  );
                  if (context.mounted && ok) Navigator.pop(context);
                },
          child: Text(
            widget.state.busy ? 'Menyimpan…' : 'Buat kantong',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ),
  );
}

class _PocketDetails extends StatelessWidget {
  final GroupPocketState state;
  final String pocketId;
  const _PocketDetails({required this.state, required this.pocketId});
  String money(String amount, String currency) => state.app.isBalanceHidden
      ? '••••••'
      : CurrencyFormatter.formatCurrency(amount, currency: currency);

  Future<void> deletePocket(BuildContext context, GroupPocket pocket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus kantong "${pocket.name}"?'),
        content: const Text(
          'Kantong ini akan dihapus dari grup. Rekening pribadi anggota yang tertaut tidak akan dihapus dan saldonya tetap aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Kantong'),
          ),
        ],
      ),
    );
    if (confirmed == true && state.canWrite) {
      final ok = await state.delete(pocket.id);
      if (context.mounted && ok) Navigator.pop(context);
    }
  }

  Future<void> unlink(BuildContext context, PocketAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lepaskan akun dari kantong?'),
        content: const Text(
          'Saldo tidak berubah. Pembagian akun ke laporan grup tetap aktif. Untuk mencabut akses grup, hentikan pembagian akun secara terpisah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lepaskan'),
          ),
        ],
      ),
    );
    if (confirmed == true && state.canWrite) {
      await state.assign(pocketId, account.id, remove: true);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final pocket = state.pockets.where((p) => p.id == pocketId).firstOrNull;
      return _PocketSheet(
        title: pocket?.name ?? 'Rincian kantong',
        subtitle: 'Rincian saldo dan kontribusi rekening anggota',
        headerActions: pocket != null
            ? [
                IconButton(
                  tooltip: 'Ubah kantong',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  onPressed: state.canWrite
                      ? () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) =>
                              _EditPocket(state: state, pocket: pocket),
                        )
                      : null,
                ),
                IconButton(
                  tooltip: 'Hapus kantong',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.expense,
                  visualDensity: VisualDensity.compact,
                  onPressed: state.canWrite
                      ? () => deletePocket(context, pocket)
                      : null,
                ),
              ]
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.loading || state.busy)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(minHeight: 2.5),
              ),
            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.expenseLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.expense,
                  ),
                ),
              ),
            if (pocket == null)
              const Text('Rincian tidak tersedia. Tutup dan muat ulang.')
            else ...[
              // Hero Balance Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'TOTAL SALDO KANTONG',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pocket.accounts.length} Akun Tertaut',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (pocket.balances.isEmpty)
                      const Text(
                        'Belum ada akun tertaut',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      )
                    else
                      for (final balance in pocket.balances)
                        Text(
                          money(balance.balance, balance.currency),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                    if (pocket.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        pocket.description!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rekening Anggota Tertaut',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Transparan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (pocket.accounts.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.link_off_rounded,
                          size: 22,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Belum ada akun tertaut, bukan saldo nol.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Tautkan rekening kas atau bank Anda di bawah untuk menggabungkan alokasi saldo secara transparan.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                for (final account in pocket.accounts) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: account.ownerId == state.owner
                              ? AppColors.primary
                              : AppColors.accent,
                          child: Text(
                            account.ownerName.isNotEmpty
                                ? account.ownerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      account.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (account.ownerId == state.owner) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Anda',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pemilik: ${account.ownerName}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              money(account.balance, account.currency),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            if (account.ownerId == state.owner)
                              InkWell(
                                onTap: state.canWrite
                                    ? () => unlink(context, account)
                                    : null,
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.link_off_rounded,
                                        size: 12,
                                        color: AppColors.expense,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        'Lepas',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.expense,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
            ],
          ],
        ),
        actions: SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: pocket != null && state.canWrite
                ? () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (_) =>
                        _AssignPocket(state: state, pocketId: pocketId),
                  )
                : null,
            icon: const Icon(Icons.add_link_rounded, size: 18),
            label: const Text(
              'Tautkan akun saya',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    },
  );
}

class _EditPocket extends StatefulWidget {
  final GroupPocketState state;
  final GroupPocket pocket;
  const _EditPocket({required this.state, required this.pocket});
  @override
  State<_EditPocket> createState() => _EditPocketState();
}

class _EditPocketState extends State<_EditPocket> {
  late final TextEditingController name;
  late final TextEditingController description;
  final form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.pocket.name);
    description = TextEditingController(text: widget.pocket.description ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) => _PocketSheet(
      title: 'Ubah Kantong',
      subtitle: 'Perbarui nama atau deskripsi kantong bersama',
      body: Form(
        key: form,
        child: Column(
          children: [
            TextFormField(
              controller: name,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: 'Nama kantong',
                prefixIcon: const Icon(Icons.savings_outlined, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: description,
              maxLength: 2000,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Deskripsi (opsional)',
                prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if (widget.state.error != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.expenseLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.state.error!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.expense,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: SizedBox(
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: !widget.state.canWrite
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  final ok = await widget.state.update(
                    widget.pocket.id,
                    name.text,
                    description.text,
                  );
                  if (context.mounted && ok) Navigator.pop(context);
                },
          child: Text(
            widget.state.busy ? 'Menyimpan…' : 'Simpan Perubahan',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ),
  );
}

class _AssignPocket extends StatefulWidget {
  final GroupPocketState state;
  final String pocketId;
  const _AssignPocket({required this.state, required this.pocketId});
  @override
  State<_AssignPocket> createState() => _AssignPocketState();
}

class _AssignPocketState extends State<_AssignPocket> {
  String? selected;
  bool consent = false;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) {
      final state = widget.state;
      final assigned = {
        for (final p in state.pockets)
          for (final a in p.accounts) a.id: p,
      };
      final candidates = state.candidates;
      final valid = candidates.any(
        (a) => a.id == selected && !assigned.containsKey(a.id),
      );
      return _PocketSheet(
        title: 'Tautkan akun saya',
        subtitle: 'Pilih rekening pribadi untuk dialokasikan ke kantong ini',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hanya akun sendiri yang aktif tanpa anak. Seluruh saldo ditampilkan kepada anggota grup beserta nama akun dan pemilik. Satu akun hanya boleh berada di satu kantong per grup.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.expenseLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.expense,
                  ),
                ),
              ),
            const Text(
              'Pilih Rekening Pribadi:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            if (candidates.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Tidak ada akun yang tersedia. Sinkronkan akun dan muat ulang kantong.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final a in candidates) ...[
                () {
                  final isAlreadyAssigned = assigned.containsKey(a.id);
                  final isSelected = selected == a.id;
                  final isSelectable = state.canWrite && !isAlreadyAssigned;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.surfaceVariant
                          : isAlreadyAssigned
                          ? AppColors.surfaceVariant.withValues(alpha: 0.3)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: InkWell(
                      onTap: isSelectable
                          ? () => setState(() => selected = a.id)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 20,
                              color: isSelected
                                  ? AppColors.primary
                                  : isAlreadyAssigned
                                  ? AppColors.border
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accentLight
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 16,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isAlreadyAssigned
                                          ? AppColors.textMuted
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAlreadyAssigned
                                        ? 'Tertaut: ${assigned[a.id]!.name}'
                                        : state.app.isBalanceHidden
                                        ? '••••••'
                                        : CurrencyFormatter.formatCurrency(
                                            a.balance,
                                            currency: a.currency,
                                          ),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isAlreadyAssigned
                                          ? AppColors.textMuted
                                          : AppColors.textSecondary,
                                      fontWeight: isAlreadyAssigned
                                          ? FontWeight.w500
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }(),
              ],
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
              ),
              child: CheckboxListTile(
                value: consent,
                activeColor: AppColors.primary,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                onChanged: state.canWrite
                    ? (v) => setState(() => consent = v ?? false)
                    : null,
                title: const Text(
                  'Saya setuju membagikan akun ini. Pembagian juga dapat menyertakan riwayat transaksi melalui pemetaan kategori laporan grup. Tidak ada dana dipindahkan.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: SizedBox(
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: state.canWrite && valid && consent
                ? () async {
                    final ok = await state.assign(
                      widget.pocketId,
                      selected!,
                      remove: false,
                    );
                    if (context.mounted && ok) Navigator.pop(context);
                  }
                : null,
            child: Text(
              state.busy ? 'Menautkan…' : 'Bagikan dan tautkan seluruh saldo',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
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
    builder: (_) => child,
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Kantong tujuan grup',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
            IconButton(
              tooltip: 'Muat ulang kantong',
              onPressed: state.available && !state.loading && !state.busy
                  ? state.load
                  : null,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Seluruh saldo akun ditautkan, bukan dipindahkan atau dicadangkan. Total terpisah per mata uang. Semua anggota aktif dapat membuat kantong.',
        ),
        if (!state.available)
          const Text('Koneksi online dan keanggotaan aktif diperlukan.'),
        if (state.loading || state.busy) const LinearProgressIndicator(),
        if (state.error != null)
          Text(
            state.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (state.fresh && state.pockets.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Belum ada kantong. Buat kantong tujuan pertama.'),
          ),
        for (final pocket in state.pockets)
          Card(
            child: ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: Text(pocket.name),
              subtitle: Text(
                [
                  if (pocket.description?.isNotEmpty == true)
                    pocket.description!,
                  if (pocket.balances.isEmpty) 'Belum ada akun tertaut',
                  for (final balance in pocket.balances)
                    money(balance.balance, balance.currency),
                  '${pocket.accounts.length} akun • lihat pemilik dan rincian',
                ].join('\n'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: state.canWrite
                  ? () =>
                        sheet(_PocketDetails(state: state, pocketId: pocket.id))
                  : null,
            ),
          ),
        FilledButton.icon(
          onPressed: state.canWrite
              ? () => sheet(_CreatePocket(state: state))
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Buat kantong'),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

/// A pinned header/footer surrounds the independently scrollable sheet body.
class _PocketSheet extends StatelessWidget {
  final String title;
  final Widget body, actions;
  const _PocketSheet({
    required this.title,
    required this.body,
    required this.actions,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: body,
              ),
            ),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(16), child: actions),
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
      body: Form(
        key: form,
        child: Column(
          children: [
            TextFormField(
              controller: name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Nama kantong'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
            ),
            TextFormField(
              controller: description,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
              ),
            ),
            if (widget.state.error != null) Text(widget.state.error!),
            if (!widget.state.available)
              const Text('Sesi atau koneksi berubah. Tutup dan muat ulang.'),
          ],
        ),
      ),
      actions: FilledButton(
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
        child: Text(widget.state.busy ? 'Menyimpan…' : 'Buat kantong'),
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.loading || state.busy) const LinearProgressIndicator(),
            if (state.error != null) Text(state.error!),
            if (pocket == null)
              const Text('Rincian tidak tersedia. Tutup dan muat ulang.'),
            if (pocket != null) ...[
              if (pocket.description != null) Text(pocket.description!),
              for (final balance in pocket.balances)
                Text(
                  money(balance.balance, balance.currency),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (pocket.accounts.isEmpty)
                const Text('Belum ada akun tertaut, bukan saldo nol.'),
              for (final account in pocket.accounts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(account.name),
                  subtitle: Text(
                    'Pemilik: ${account.ownerName}\n${money(account.balance, account.currency)}',
                  ),
                  trailing: account.ownerId == state.owner
                      ? IconButton(
                          tooltip: 'Lepaskan akun',
                          icon: const Icon(Icons.link_off),
                          onPressed: state.canWrite
                              ? () => unlink(context, account)
                              : null,
                        )
                      : null,
                ),
            ],
          ],
        ),
        actions: FilledButton.icon(
          onPressed: pocket != null && state.canWrite
              ? () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) =>
                      _AssignPocket(state: state, pocketId: pocketId),
                )
              : null,
          icon: const Icon(Icons.add_link),
          label: const Text('Tautkan akun saya'),
        ),
      );
    },
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
        body: Column(
          children: [
            const Text(
              'Hanya akun sendiri yang aktif tanpa anak. Seluruh saldo ditampilkan kepada anggota grup beserta nama akun dan pemilik. Satu akun hanya boleh berada di satu kantong per grup.',
            ),
            if (state.error != null) Text(state.error!),
            if (candidates.isEmpty)
              const Text(
                'Tidak ada akun yang tersedia. Sinkronkan akun dan muat ulang kantong.',
              ),
            for (final a in candidates)
              ListTile(
                leading: Icon(
                  selected == a.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(a.name),
                subtitle: Text(
                  assigned.containsKey(a.id)
                      ? 'Tertaut: ${assigned[a.id]!.name}'
                      : state.app.isBalanceHidden
                      ? '••••••'
                      : CurrencyFormatter.formatCurrency(
                          a.balance,
                          currency: a.currency,
                        ),
                ),
                enabled: state.canWrite && !assigned.containsKey(a.id),
                onTap: state.canWrite && !assigned.containsKey(a.id)
                    ? () => setState(() => selected = a.id)
                    : null,
              ),
            CheckboxListTile(
              value: consent,
              onChanged: state.canWrite
                  ? (v) => setState(() => consent = v ?? false)
                  : null,
              title: const Text(
                'Saya setuju membagikan akun ini. Pembagian juga dapat menyertakan riwayat transaksi melalui pemetaan kategori laporan grup. Tidak ada dana dipindahkan.',
              ),
            ),
          ],
        ),
        actions: FilledButton(
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
          ),
        ),
      );
    },
  );
}

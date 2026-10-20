import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../data/portfolio_controller.dart';
import '../data/portfolio_repository.dart';
import 'investment_lifecycle_page.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});
  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  PortfolioController? _controller;
  String? _scopeKey;
  bool? _offline;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final source = state.repository;
    final userId = state.currentUserId;
    final valid =
        source != null && userId.isNotEmpty && source.userId == userId;
    if (!valid || !identical(_controller?.repository.source, source)) {
      _controller?.dispose();
      _controller = valid
          ? PortfolioController(
              PortfolioRepository(source),
              () =>
                  identical(state.repository, source) &&
                  state.currentUserId == userId,
            )
          : null;
      _scopeKey = null;
    }
    final controller = _controller;
    if (controller == null) return;
    final accounts = controller.repository.accounts;
    final id = accounts.any((a) => a.id == controller.accountId)
        ? controller.accountId
        : accounts.firstOrNull?.id;
    final key = '$userId:${accounts.map((a) => a.id).join(',')}:$id';
    if (_scopeKey != key || _offline != state.isOfflineMode) {
      _scopeKey = key;
      _offline = state.isOfflineMode;
      unawaited(controller.select(id, controller.date));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _chooseDate(PortfolioController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.date ?? '') ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (!mounted || picked == null || !identical(_controller, controller)) {
      return;
    }
    final date =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await controller.select(controller.accountId, date);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hidden = AppStateScope.of(context).isBalanceHidden;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portofolio investasi'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => const InvestmentLifecyclePage(),
              ),
            ),
            child: const Text('Kelola'),
          ),
        ],
      ),
      body: controller == null
          ? const Center(
              child: Text(
                'Masuk dan siapkan data akun untuk melihat portofolio.',
              ),
            )
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final accounts = controller.repository.accounts;
                final read = controller.read;
                String amount(String? value) => hidden
                    ? '••••••'
                    : value == null
                    ? 'Harga belum tersedia'
                    : 'IDR $value';
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Hanya baca • Data server, bukan ledger lokal tersinkron lengkap. Beli/jual dan pembaruan harga tidak tersedia di layar ini.',
                    ),
                    const SizedBox(height: 16),
                    if (accounts.isEmpty)
                      const Text('Belum ada akun investasi milik Anda.')
                    else ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey(controller.accountId),
                        initialValue: controller.accountId,
                        decoration: const InputDecoration(
                          labelText: 'Akun investasi milik Anda',
                        ),
                        isExpanded: true,
                        items: accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            )
                            .toList(),
                        onChanged: (id) =>
                            unawaited(controller.select(id, controller.date)),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => unawaited(
                              controller.select(controller.accountId, null),
                            ),
                            child: const Text('Holdings saat ini'),
                          ),
                          TextButton(
                            onPressed: () => _chooseDate(controller),
                            child: Text(
                              controller.date == null
                                  ? 'Pilih tanggal snapshot'
                                  : 'Snapshot ${controller.date}',
                            ),
                          ),
                          TextButton(
                            onPressed: controller.loading
                                ? null
                                : () => unawaited(
                                    controller.select(
                                      controller.accountId,
                                      controller.date,
                                    ),
                                  ),
                            child: const Text('Muat ulang'),
                          ),
                        ],
                      ),
                      Text(
                        controller.date == null
                            ? 'Posisi saat ini (holdings)'
                            : 'Posisi per ${controller.date} — snapshot',
                      ),
                      if (controller.loading) const LinearProgressIndicator(),
                      if (controller.error != null) Text(controller.error!),
                      if (read != null) ...[
                        Text(
                          'Cache diambil: ${read.fetchedAt.toLocal().toIso8601String()}',
                        ),
                        Text(
                          controller.stale
                              ? 'Data cache usang / belum diverifikasi ulang.'
                              : 'Terakhir berhasil dimuat dari server; bukan harga real-time.',
                        ),
                        if (read.positions.isEmpty)
                          const Text(
                            'Tidak ada posisi untuk akun dan periode ini.',
                          ),
                        for (final position in read.positions)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${position.code} • ${position.name}'),
                                  Text(
                                    'Jumlah: ${hidden ? '••••••' : position.quantity}',
                                  ),
                                  Text(
                                    'Harga modal rata-rata: ${amount(position.average)}',
                                  ),
                                  if (controller.date != null) ...[
                                    Text(
                                      'Harga pasar: ${amount(position.marketPrice)}',
                                    ),
                                    Text(
                                      'Nilai pasar: ${amount(position.marketValue)}',
                                    ),
                                    Text(
                                      'Laba/rugi belum terealisasi: ${amount(position.unrealizedPl)}',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ] else if (!controller.loading)
                        const Text(
                          'Belum ada cache portofolio untuk pilihan ini.',
                        ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

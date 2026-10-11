import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repository.dart';

class SecurityPage extends StatefulWidget {
  final AuthRepository auth;
  final Future<void> Function() onLogout;

  const SecurityPage({super.key, required this.auth, required this.onLogout});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool _busy = false;
  String? _error;

  Future<void> _remember(bool value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.setRememberMe(value);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiFailure
              ? error.message
              : 'Pengaturan sesi tidak dapat disimpan.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout perangkat ini?'),
        content: const Text(
          'Data lokal tetap tersimpan. Anda perlu login kembali untuk sinkronisasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var failed = false;
    try {
      await widget.onLogout();
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed
              ? 'Sesi lokal dihapus. Pencabutan sesi server tidak dapat dikonfirmasi.'
              : 'Anda telah logout dari perangkat ini.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Keamanan & Sesi')),
    body: ListView(
      children: [
        SwitchListTile(
          title: const Text('Ingat saya'),
          subtitle: const Text(
            'Simpan sesi untuk masuk kembali saat aplikasi dibuka. Jika dimatikan, sesi saat ini tetap aktif tetapi tidak disimpan untuk pembukaan berikutnya.',
          ),
          value: widget.auth.rememberMe,
          onChanged: _busy ? null : _remember,
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Kunci aplikasi'),
          subtitle: Text(
            'PIN dan biometrik belum tersedia. Pengaturan ini hanya mengelola penyimpanan sesi pada perangkat ini.',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Logout perangkat ini'),
          subtitle: const Text(
            'Hapus sesi lokal dan coba cabut sesi saat ini di server. Data keuangan lokal tetap tersimpan.',
          ),
          enabled: !_busy,
          onTap: _logout,
        ),
        if (_busy) const Center(child: CircularProgressIndicator()),
      ],
    ),
  );
}

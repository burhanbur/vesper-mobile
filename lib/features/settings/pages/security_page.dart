import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_lock_gate.dart';
import '../../../core/network/api_client.dart';
import '../../../core/security/app_lock_controller.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.expense, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Logout perangkat ini?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Data lokal tetap tersimpan di perangkat ini. Anda perlu login kembali untuk melakukan sinkronisasi dengan server.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
        behavior: SnackBarBehavior.floating,
        content: Text(
          failed
              ? 'Sesi lokal dihapus. Pencabutan sesi server tidak dapat dikonfirmasi.'
              : 'Anda telah logout dari perangkat ini.',
        ),
      ),
    );
  }

  Future<void> _openChangePasswordSheet() async {
    final revoked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(auth: widget.auth),
    );
    if (revoked == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        content: Text(
          revoked > 0
              ? 'Kata sandi diubah. $revoked sesi perangkat lain dicabut.'
              : 'Kata sandi berhasil diubah.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lock = AppLockScope.maybeOf(context);
    final lockEnabled = lock?.enabled == true;
    final rememberMe = widget.auth.rememberMe;
    final isBusy = _busy || (lock?.busy ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Keamanan & Sesi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (isBusy) ...[
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 1. Hero Security Status Card
          _buildHeroCard(
            lockAvailable: lock != null,
            lockEnabled: lockEnabled,
            rememberMe: rememberMe,
          ),
          const SizedBox(height: 20),

          // 2. Device Protection Section
          _buildSectionLabel('PERLINDUNGAN PERANGKAT'),
          const SizedBox(height: 8),
          _buildAppLockCard(context, lock),
          const SizedBox(height: 20),

          // 3. Session Settings Section
          _buildSectionLabel('PENGATURAN SESI'),
          const SizedBox(height: 8),
          Material(
            color: AppColors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  secondary: _IconBadge(
                    icon: Icons.key_rounded,
                    fg: rememberMe ? AppColors.primary : AppColors.textMuted,
                    bg: rememberMe
                        ? AppColors.accentLight
                        : AppColors.surfaceVariant,
                  ),
                  title: const Text(
                    'Ingat saya',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Simpan sesi untuk masuk kembali saat aplikasi dibuka. Jika dimatikan, sesi saat ini tetap aktif tetapi tidak disimpan untuk pembukaan berikutnya.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  activeThumbColor: AppColors.primary,
                  value: rememberMe,
                  onChanged: _busy ? null : _remember,
                ),
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.borderSubtle,
                ),
                ListTile(
                  key: const ValueKey('change_password_tile'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: const _IconBadge(
                    icon: Icons.password_rounded,
                    fg: AppColors.primary,
                    bg: AppColors.accentLight,
                  ),
                  title: const Text(
                    'Ubah kata sandi',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Perbarui kata sandi akun dan otomatis cabut sesi di perangkat lain.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                  enabled: !_busy,
                  onTap: _openChangePasswordSheet,
                ),
                if (_error != null)
                  _ErrorBanner(message: _error!, liveRegion: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Session Action / Logout Section
          _buildSectionLabel('AKSI SESI'),
          const SizedBox(height: 8),
          Material(
            color: AppColors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.expense.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const _IconBadge(
                icon: Icons.logout_rounded,
                fg: AppColors.expense,
                bg: AppColors.expenseLight,
              ),
              title: const Text(
                'Logout perangkat ini',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.expense,
                ),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Hapus sesi lokal dan coba cabut sesi saat ini di server. Data keuangan lokal tetap tersimpan.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.expense,
              ),
              enabled: !_busy,
              onTap: _logout,
            ),
          ),
          const SizedBox(height: 16),

          // 5. Security Info Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kunci aplikasi memakai keamanan perangkat. Pada browser, kunci ini tidak tersedia dan data lokal tidak terenkripsi. Gunakan profil browser pribadi pada perangkat tepercaya.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required bool lockAvailable,
    required bool lockEnabled,
    required bool rememberMe,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryGradientStart,
            AppColors.primaryGradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  lockEnabled
                      ? Icons.verified_user_rounded
                      : Icons.security_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lockEnabled
                          ? 'Perlindungan Ekstra Aktif'
                          : 'Keamanan Standar',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lockEnabled
                          ? 'Akses aplikasi dilindungi biometrik / kunci perangkat'
                          : 'Aktifkan kunci aplikasi untuk melindungi data finansial',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroStatusPill(
                dotColor: lockEnabled
                    ? const Color(0xFF34D399)
                    : const Color(0xFFFBBF24),
                label: !lockAvailable
                    ? 'Kunci Tidak Tersedia'
                    : lockEnabled
                    ? 'Kunci Aplikasi Aktif'
                    : 'Kunci Aplikasi Nonaktif',
              ),
              _HeroStatusPill(
                dotColor: rememberMe
                    ? const Color(0xFF34D399)
                    : Colors.white54,
                label: rememberMe ? 'Sesi Tersimpan' : 'Sesi Sementara',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppLockCard(BuildContext context, AppLockController? lock) {
    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: lock == null
          ? const ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: _IconBadge(
                icon: Icons.lock_rounded,
                fg: AppColors.textMuted,
                bg: AppColors.surfaceVariant,
              ),
              title: Text(
                'Kunci aplikasi',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Kunci perangkat tidak tersedia pada sesi ini.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  secondary: _IconBadge(
                    icon: Icons.lock_rounded,
                    fg: lock.enabled ? AppColors.primary : AppColors.textMuted,
                    bg: lock.enabled
                        ? AppColors.accentLight
                        : AppColors.surfaceVariant,
                  ),
                  title: const Text(
                    'Kunci aplikasi',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Minta biometrik atau PIN/sandi perangkat saat aplikasi dibuka dan setelah meninggalkan aplikasi. Berlaku untuk semua akun pada perangkat ini. Data dan antrean tetap tersimpan.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  activeThumbColor: AppColors.primary,
                  value: lock.enabled,
                  onChanged: _busy || lock.busy || !lock.loaded
                      ? null
                      : lock.setEnabled,
                ),
                if (lock.error != null)
                  _ErrorBanner(message: lock.error!, liveRegion: true),
              ],
            ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color fg;
  final Color bg;

  const _IconBadge({required this.icon, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: fg, size: 22),
    );
  }
}

class _HeroStatusPill extends StatelessWidget {
  final Color dotColor;
  final String label;

  const _HeroStatusPill({required this.dotColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool liveRegion;

  const _ErrorBanner({required this.message, this.liveRegion = false});

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      message,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.expense,
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.expenseLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.expense,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: liveRegion
                ? Semantics(liveRegion: true, child: textWidget)
                : textWidget,
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  final AuthRepository auth;

  const _ChangePasswordSheet({required this.auth});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty) {
      setState(() => _error = 'Kata sandi saat ini wajib diisi.');
      return;
    }
    if (next.length < 8 || next.length > 128) {
      setState(() => _error = 'Kata sandi baru harus 8–128 karakter.');
      return;
    }
    if (next == current) {
      setState(
        () => _error = 'Kata sandi baru harus berbeda dari kata sandi saat ini.',
      );
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'Konfirmasi kata sandi tidak sama.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final revoked = await widget.auth.changePassword(
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      Navigator.of(context).pop(revoked);
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Kata sandi gagal diperbarui. Silakan coba lagi.';
          _saving = false;
        });
      }
    }
  }

  Widget _buildPasswordField({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required TextInputAction textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          obscureText: obscure,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: onToggleObscure,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ubah Kata Sandi',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPasswordField(
                fieldKey: const ValueKey('current_password_field'),
                controller: _currentController,
                label: 'Kata sandi saat ini',
                hint: 'Masukkan kata sandi saat ini',
                obscure: _obscureCurrent,
                onToggleObscure: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _buildPasswordField(
                fieldKey: const ValueKey('new_password_field'),
                controller: _newController,
                label: 'Kata sandi baru',
                hint: 'Minimal 8 karakter',
                obscure: _obscureNew,
                onToggleObscure: () =>
                    setState(() => _obscureNew = !_obscureNew),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _buildPasswordField(
                fieldKey: const ValueKey('confirm_password_field'),
                controller: _confirmController,
                label: 'Konfirmasi kata sandi baru',
                hint: 'Ulangi kata sandi baru',
                obscure: _obscureConfirm,
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.expenseLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.expense.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: AppColors.expense,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.expense,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                key: const ValueKey('submit_change_password_button'),
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Simpan Kata Sandi Baru',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

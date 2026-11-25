import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/devices_repository.dart';

class DevicesPage extends StatefulWidget {
  final DevicesRepository repository;
  final String? currentDeviceId;
  final Future<void> Function()? onBeforeLoad;

  const DevicesPage({
    super.key,
    required this.repository,
    this.currentDeviceId,
    this.onBeforeLoad,
  });

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  late Future<List<RegisteredDevice>> _devices;

  @override
  void initState() {
    super.initState();
    _devices = _fetchDevices();
  }

  Future<List<RegisteredDevice>> _fetchDevices() {
    final before = widget.onBeforeLoad;
    if (before == null) {
      return widget.repository.list();
    }
    return () async {
      try {
        await before();
      } catch (_) {
        // Best-effort metadata sync; never block reading registered devices.
      }
      return widget.repository.list();
    }();
  }

  void _retry() {
    setState(() {
      _devices = _fetchDevices();
    });
  }

  Future<void> _refresh() async {
    _retry();
    try {
      await _devices;
    } catch (_) {
      // FutureBuilder displays the failure and retry action.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Device Terdaftar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang',
            onPressed: _retry,
          ),
        ],
      ),
      body: FutureBuilder<List<RegisteredDevice>>(
        future: _devices,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 14),
                  Text(
                    'Memuat perangkat terdaftar...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is ApiFailure
                ? error.message
                : 'Daftar perangkat tidak dapat dimuat.';
            return _buildStateCard(
              icon: Icons.cloud_off_rounded,
              iconColor: AppColors.expense,
              iconBg: AppColors.expenseLight,
              title: 'Gagal memuat perangkat',
              message: message,
              buttonLabel: 'Coba lagi',
              onPressed: _retry,
            );
          }

          final devices = snapshot.data ?? [];
          if (devices.isEmpty) {
            return _buildStateCard(
              icon: Icons.devices_other_rounded,
              iconColor: AppColors.primary,
              iconBg: AppColors.accentLight,
              title: 'Belum ada perangkat terdaftar.',
              message:
                  'Perangkat Anda akan otomatis tercatat setelah sinkronisasi berhasil.',
              buttonLabel: 'Muat ulang',
              onPressed: _retry,
            );
          }

          // Read again after loading: registration may have completed meanwhile.
          final currentId =
              widget.currentDeviceId ??
              AppStateScope.of(context).repository?.state['device_id']
                  as String?;

          final currentDevices = <RegisteredDevice>[];
          final otherDevices = <RegisteredDevice>[];
          for (final device in devices) {
            if (currentId != null && device.id == currentId) {
              currentDevices.add(device);
            } else {
              otherDevices.add(device);
            }
          }
          otherDevices.sort(_compareByRecencyDesc);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _buildHeroSummary(devices),
                const SizedBox(height: 20),
                if (currentDevices.isNotEmpty) ...[
                  _buildSectionLabel('PERANGKAT SAAT INI'),
                  const SizedBox(height: 8),
                  for (final device in currentDevices) ...[
                    _DeviceCard(device: device, isCurrent: true),
                    const SizedBox(height: 12),
                  ],
                  if (otherDevices.isNotEmpty) const SizedBox(height: 8),
                ],
                if (otherDevices.isNotEmpty) ...[
                  _buildSectionLabel(
                    currentDevices.isNotEmpty
                        ? 'PERANGKAT LAINNYA (${otherDevices.length})'
                        : 'DAFTAR PERANGKAT (${otherDevices.length})',
                  ),
                  const SizedBox(height: 8),
                  for (final device in otherDevices) ...[
                    _DeviceCard(device: device, isCurrent: false),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 4),
                _buildInfoNotice(),
              ],
            ),
          );
        },
      ),
    );
  }

  static int _compareByRecencyDesc(RegisteredDevice a, RegisteredDevice b) {
    final aTime = a.lastActiveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.lastActiveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  }

  Widget _buildHeroSummary(List<RegisteredDevice> devices) {
    final androidCount = devices.where((d) => d.platform == 'Android').length;
    final iosCount = devices.where((d) => d.platform == 'iOS').length;
    final webCount = devices.where((d) => d.platform == 'Web').length;

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
        borderRadius: BorderRadius.circular(18),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.devices_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${devices.length} Perangkat Terdaftar',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Terhubung untuk sinkronisasi data keuangan Anda',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
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
              if (androidCount > 0)
                _buildHeroChip(
                  Icons.phone_android_rounded,
                  '$androidCount Android',
                ),
              if (iosCount > 0)
                _buildHeroChip(Icons.phone_iphone_rounded, '$iosCount iOS'),
              if (webCount > 0)
                _buildHeroChip(Icons.laptop_mac_rounded, '$webCount Web'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
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
          Icon(icon, size: 13, color: AppColors.accentLight),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
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

  Widget _buildInfoNotice() {
    return Container(
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
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Perangkat yang ditampilkan adalah perangkat terdaftar untuk sinkronisasi, bukan daftar sesi aktif. Fitur logout perangkat lain dari jarak jauh belum tersedia.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final RegisteredDevice device;
  final bool isCurrent;

  const _DeviceCard({required this.device, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final style = _platformStyle(device.platform, isCurrent);
    final lastActive = device.lastActiveAt;
    final recencyLabel = lastActive != null ? _relativeLabel(lastActive) : null;
    final osChipLabel = _buildOsChipLabel(device);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary.withValues(alpha: 0.38)
              : AppColors.border,
          width: isCurrent ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCurrent ? AppColors.primary : Colors.black).withValues(
              alpha: isCurrent ? 0.08 : 0.03,
            ),
            blurRadius: isCurrent ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.icon, color: style.fg, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            device.displayName,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.incomeLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.income.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.income,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Perangkat ini',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.income,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaPill(
                          label: osChipLabel,
                          bg: style.bg,
                          fg: style.fg,
                        ),
                        _MetaPill(
                          label: 'Vesper v${device.appVersion}',
                          bg: AppColors.surfaceVariant,
                          fg: AppColors.textSecondary,
                        ),
                        if (recencyLabel != null)
                          _MetaPill(
                            label: recencyLabel,
                            bg: AppColors.infoLight,
                            fg: AppColors.info,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.login_rounded,
                  label: 'Terakhir login / aktif',
                  value: lastActive != null
                      ? DateFormatter.formatFull(lastActive)
                      : 'Belum tercatat',
                  highlight: isCurrent && lastActive != null,
                ),
                const Divider(height: 14, color: AppColors.borderSubtle),
                _DetailRow(
                  icon: Icons.sync_rounded,
                  label: 'Sinkronisasi terakhir',
                  value: device.lastSyncAt != null
                      ? DateFormatter.formatFull(device.lastSyncAt!)
                      : 'Belum pernah sinkron',
                ),
                if (device.createdAt != null) ...[
                  const Divider(height: 14, color: AppColors.borderSubtle),
                  _DetailRow(
                    icon: Icons.event_available_rounded,
                    label: 'Pertama terdaftar',
                    value: DateFormatter.formatFull(device.createdAt!),
                  ),
                ],
                const Divider(height: 14, color: AppColors.borderSubtle),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: device.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ID perangkat disalin ke clipboard.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: _DetailRow(
                    icon: Icons.fingerprint_rounded,
                    label: 'ID Perangkat',
                    value: device.shortId,
                    trailingIcon: Icons.copy_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _buildOsChipLabel(RegisteredDevice device) {
    final os = device.osDetail;
    if (os == null) return device.platform;
    if (os.toLowerCase().contains(device.platform.toLowerCase())) {
      return os;
    }
    return '${device.platform} • $os';
  }

  static String? _relativeLabel(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.isNegative) return 'Baru saja';
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return null;
  }

  static ({IconData icon, Color fg, Color bg}) _platformStyle(
    String platform,
    bool isCurrent,
  ) {
    switch (platform) {
      case 'Android':
        return (
          icon: Icons.phone_android_rounded,
          fg: isCurrent ? AppColors.primary : AppColors.income,
          bg: isCurrent ? AppColors.accentLight : AppColors.incomeLight,
        );
      case 'iOS':
        return (
          icon: Icons.phone_iphone_rounded,
          fg: AppColors.textPrimary,
          bg: AppColors.surfaceVariant,
        );
      case 'Web':
        return (
          icon: Icons.laptop_mac_rounded,
          fg: AppColors.transfer,
          bg: AppColors.transferLight,
        );
      default:
        return (
          icon: Icons.devices_rounded,
          fg: AppColors.primary,
          bg: AppColors.accentLight,
        );
    }
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _MetaPill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final IconData? trailingIcon;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: highlight ? AppColors.income : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                    color: highlight ? AppColors.income : AppColors.textPrimary,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 5),
                Icon(trailingIcon, size: 13, color: AppColors.textMuted),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

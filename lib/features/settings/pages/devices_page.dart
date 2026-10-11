import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/network/api_client.dart';
import '../data/devices_repository.dart';

class DevicesPage extends StatefulWidget {
  final DevicesRepository repository;
  final String? currentDeviceId;

  const DevicesPage({
    super.key,
    required this.repository,
    this.currentDeviceId,
  });

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  late Future<List<RegisteredDevice>> _devices;

  @override
  void initState() {
    super.initState();
    _devices = widget.repository.list();
  }

  void _retry() {
    setState(() {
      _devices = widget.repository.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Terdaftar')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Perangkat yang terdaftar untuk sinkronisasi, bukan daftar sesi aktif. Logout perangkat lain belum tersedia.',
            ),
          ),
          Expanded(
            child: FutureBuilder<List<RegisteredDevice>>(
              future: _devices,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error is ApiFailure
                              ? error.message
                              : 'Daftar perangkat tidak dapat dimuat.',
                        ),
                        TextButton(
                          onPressed: _retry,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  );
                }
                final devices = snapshot.data ?? [];
                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Belum ada perangkat terdaftar.'),
                        TextButton(
                          onPressed: _retry,
                          child: const Text('Muat ulang'),
                        ),
                      ],
                    ),
                  );
                }
                // Read again after loading: registration may have completed meanwhile.
                final currentId =
                    widget.currentDeviceId ??
                    AppStateScope.of(context).repository?.state['device_id'];
                return RefreshIndicator(
                  onRefresh: () async {
                    _retry();
                    try {
                      await _devices;
                    } catch (_) {
                      // FutureBuilder displays the failure and retry action.
                    }
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return ListTile(
                        leading: const Icon(Icons.devices_rounded),
                        title: Text(device.name),
                        subtitle: Text(
                          '${device.platform} • ${device.appVersion}',
                        ),
                        trailing: device.id == currentId
                            ? const Text('Perangkat ini')
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

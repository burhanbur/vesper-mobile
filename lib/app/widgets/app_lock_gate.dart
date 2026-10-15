import 'package:flutter/material.dart';

import '../../core/security/app_lock_controller.dart';

/// PopScope needs a ModalRoute ancestor. The visual gate sits above Navigator,
/// so register a pop guard on every root route, including dialogs and sheets.
class AppLockRouteObserver extends NavigatorObserver {
  final AppLockController controller;
  final Map<ModalRoute<dynamic>, _LockPopEntry> _entries = {};

  AppLockRouteObserver(this.controller) {
    controller.addListener(_changed);
  }

  void _changed() {
    for (final entry in _entries.values) {
      entry.canPopNotifier.value = !controller.blocksContent;
    }
  }

  void _register(Route<dynamic>? route) {
    if (route is ModalRoute<dynamic>) {
      final entry = _LockPopEntry(!controller.blocksContent);
      _entries[route] = entry;
      route.registerPopEntry(entry);
    }
  }

  void _unregister(Route<dynamic>? route) {
    if (route is ModalRoute<dynamic>) {
      final entry = _entries.remove(route);
      if (entry != null) {
        route.unregisterPopEntry(entry);
        entry.canPopNotifier.dispose();
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _register(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _unregister(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _unregister(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _unregister(oldRoute);
    _register(newRoute);
  }

  void dispose() {
    controller.removeListener(_changed);
    for (final route in _entries.keys.toList()) {
      _unregister(route);
    }
  }
}

class _LockPopEntry extends PopEntry<Object?> {
  @override
  final ValueNotifier<bool> canPopNotifier;
  _LockPopEntry(bool canPop) : canPopNotifier = ValueNotifier(canPop);
  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {}
}

class AppLockScope extends InheritedNotifier<AppLockController> {
  const AppLockScope({
    super.key,
    required AppLockController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLockController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLockScope>()?.notifier;
}

/// Above the Navigator: dialogs, routes, focus and semantics are all concealed.
/// Offstage retains drafts and scroll state while preventing painting/hit tests.
class AppLockGate extends StatefulWidget {
  final AppLockController controller;
  final Widget child;
  const AppLockGate({super.key, required this.controller, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      widget.controller.lock(
        invalidatePrompt:
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final lock = widget.controller;
      final blocked = lock.blocksContent;
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: blocked,
            child: TickerMode(
              enabled: !blocked,
              child: ExcludeFocus(excluding: blocked, child: widget.child),
            ),
          ),
          if (blocked)
            PopScope(
              canPop: false,
              child: Scaffold(
                body: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Vesper terkunci',
                            style: TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Buka dengan keamanan perangkat Anda.',
                            textAlign: TextAlign.center,
                          ),
                          if (lock.error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  lock.error!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (lock.busy || (!lock.loaded && lock.error == null))
                            const CircularProgressIndicator(
                              semanticsLabel: 'Memverifikasi keamanan',
                            )
                          else
                            FilledButton.icon(
                              onPressed: lock.loaded
                                  ? lock.unlock
                                  : lock.initialize,
                              icon: const Icon(Icons.fingerprint),
                              label: Text(
                                lock.loaded ? 'Buka aplikasi' : 'Coba lagi',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

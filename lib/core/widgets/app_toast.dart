import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum ToastType { error, success, warning, info }

/// Floating toast/flash message rendered in the root [Overlay]
/// so it displays above bottom sheets, dialogs, and navigation routes.
class AppToast {
  const AppToast._();

  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  /// Shows an error toast with crimson styling.
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    show(context, message: message, type: ToastType.error, duration: duration);
  }

  /// Shows a success toast with emerald green styling.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.success,
      duration: duration,
    );
  }

  /// Shows a warning toast with amber styling.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      type: ToastType.warning,
      duration: duration,
    );
  }

  /// Shows an info toast with neutral dark styling.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message: message, type: ToastType.info, duration: duration);
  }

  /// Immediately dismisses any active toast.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_activeEntry != null) {
      if (_activeEntry!.mounted) {
        _activeEntry!.remove();
      }
      _activeEntry = null;
    }
  }

  /// Displays a floating flash message overlay.
  static void show(
    BuildContext context, {
    required String message,
    required ToastType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    dismiss();

    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ??
        Overlay.maybeOf(context, rootOverlay: false);

    if (overlay == null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _bgColor(type),
          ),
        );
      }
      return;
    }

    final entry = OverlayEntry(
      builder: (ctx) =>
          _ToastOverlayWidget(message: message, type: type, onDismiss: dismiss),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  static Color _bgColor(ToastType type) {
    switch (type) {
      case ToastType.error:
        return const Color(0xFFDC2626); // Crimson red
      case ToastType.success:
        return const Color(0xFF16A34A); // Emerald green
      case ToastType.warning:
        return const Color(0xFFD97706); // Amber
      case ToastType.info:
        return AppColors.primaryDark;
    }
  }
}

class _ToastOverlayWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastOverlayWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlayWidget> createState() => _ToastOverlayWidgetState();
}

class _ToastOverlayWidgetState extends State<_ToastOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  Color get _backgroundColor {
    switch (widget.type) {
      case ToastType.error:
        return const Color(0xFFDC2626);
      case ToastType.success:
        return const Color(0xFF16A34A);
      case ToastType.warning:
        return const Color(0xFFD97706);
      case ToastType.info:
        return AppColors.primaryDark;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.error:
        return Icons.error_outline_rounded;
      case ToastType.success:
        return Icons.check_circle_outline_rounded;
      case ToastType.warning:
        return Icons.warning_amber_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _handleDismiss,
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null &&
                    details.primaryDelta! < -4) {
                  _handleDismiss();
                }
              },
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(_icon, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _handleDismiss,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Management lists and their account details opt into shell navigation.
/// Other pushes retain their enclosing navigator behavior.
class ShellManagementScope extends InheritedWidget {
  const ShellManagementScope({
    super.key,
    required this.openPage,
    required super.child,
  });

  final ValueChanged<Widget> openPage;

  static void open(BuildContext context, Widget page) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ShellManagementScope>();
    if (scope != null) {
      scope.openPage(page);
    } else {
      // Standalone pages (for example a fullscreen household route) have no
      // shell to target and retain their existing navigation behavior.
      Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: (_) => page));
    }
  }

  @override
  bool updateShouldNotify(ShellManagementScope oldWidget) =>
      openPage != oldWidget.openPage;
}

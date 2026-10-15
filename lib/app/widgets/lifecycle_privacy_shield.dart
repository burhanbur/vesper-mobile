import 'package:flutter/material.dart';

/// Conceals application content while inactive. Not an authentication lock.
class LifecyclePrivacyShield extends StatefulWidget {
  final Widget child;
  const LifecyclePrivacyShield({super.key, required this.child});

  @override
  State<LifecyclePrivacyShield> createState() => _LifecyclePrivacyShieldState();
}

class _LifecyclePrivacyShieldState extends State<LifecyclePrivacyShield>
    with WidgetsBindingObserver {
  bool _concealed = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _concealed = lifecycle != null && lifecycle != AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final concealed = state != AppLifecycleState.resumed;
    if (_concealed != concealed && mounted) {
      setState(() => _concealed = concealed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeSemantics(
        excluding: _concealed,
        child: IgnorePointer(ignoring: _concealed, child: widget.child),
      ),
      if (_concealed)
        Positioned.fill(
          child: const ColoredBox(
            color: Color(0xFFF7F8FA),
            child: Center(child: Icon(Icons.shield_outlined, size: 48)),
          ),
        ),
    ],
  );
}

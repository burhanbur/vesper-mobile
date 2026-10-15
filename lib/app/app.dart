import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/onboarding_page.dart';
import '../features/auth/pages/splash_page.dart';
import '../core/security/app_lock_controller.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/main_shell.dart';
import 'widgets/lifecycle_privacy_shield.dart';
import 'widgets/app_lock_gate.dart';

class VesperApp extends StatefulWidget {
  final bool initialAuthenticated;
  final bool initialShowSplash;
  final bool initialShowOnboarding;
  final AppFlowStep? initialFlow;

  const VesperApp({
    super.key,
    this.initialAuthenticated = false,
    this.initialShowSplash = false,
    this.initialShowOnboarding = false,
    this.initialFlow,
  });

  @override
  State<VesperApp> createState() => _VesperAppState();
}

class _VesperAppState extends State<VesperApp> {
  late final AppState _appState;
  late final AppLockController _appLock;
  late AppLockRouteObserver _lockRouteObserver;
  String _identity = '';
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void _identityChanged() {
    if (_identity == _appState.currentUserId) return;
    _identity = _appState.currentUserId;
    _appLock.lock(invalidatePrompt: true);
    // A lock preserves the current user's drafts. A different identity must
    // never inherit the previous user's routes, dialogs or unsaved forms.
    if (mounted) {
      _lockRouteObserver.dispose();
      setState(() {
        _navigatorKey = GlobalKey<NavigatorState>();
        _lockRouteObserver = AppLockRouteObserver(_appLock);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _appLock = AppLockController()..initialize();
    _lockRouteObserver = AppLockRouteObserver(_appLock);
    AppFlowStep startingFlow;
    if (widget.initialFlow != null) {
      startingFlow = widget.initialFlow!;
    } else if (widget.initialShowSplash) {
      startingFlow = AppFlowStep.splash;
    } else if (widget.initialShowOnboarding) {
      startingFlow = AppFlowStep.onboarding;
    } else if (widget.initialAuthenticated) {
      startingFlow = AppFlowStep.main;
    } else {
      startingFlow = AppFlowStep.auth;
    }

    _appState = AppState(
      isAuthenticated: widget.initialAuthenticated,
      initialFlow: startingFlow,
    );
    _appState.addListener(_identityChanged);
    _appState.startAutomaticSync(
      Connectivity().onConnectivityChanged.map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      ),
    );
    if (startingFlow != AppFlowStep.splash) _appState.bootstrap();
  }

  @override
  void dispose() {
    _appState.removeListener(_identityChanged);
    _appState.dispose();
    _lockRouteObserver.dispose();
    _appLock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: _appState,
      child: AppLockScope(
        controller: _appLock,
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          navigatorObservers: [_lockRouteObserver],
          title: 'Vesper Finance',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) => LifecyclePrivacyShield(
            child: AppLockGate(
              controller: _appLock,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: ListenableBuilder(
            listenable: _appState,
            builder: (context, _) {
              Widget currentScreen;
              switch (_appState.currentFlow) {
                case AppFlowStep.splash:
                  currentScreen = SplashPage(
                    key: const ValueKey('splash_page'),
                    onFinish: () {
                      _appState.bootstrap();
                    },
                  );
                  break;
                case AppFlowStep.onboarding:
                  currentScreen = OnboardingPage(
                    key: const ValueKey('onboarding_page'),
                    onFinish: () {
                      _appState.completeOnboarding();
                    },
                  );
                  break;
                case AppFlowStep.auth:
                  currentScreen = const LoginPage(key: ValueKey('login_page'));
                  break;
                case AppFlowStep.main:
                  currentScreen = const MainShell(key: ValueKey('main_shell'));
                  break;
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: currentScreen,
              );
            },
          ),
        ),
      ),
    );
  }
}

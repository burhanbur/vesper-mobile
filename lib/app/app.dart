import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/onboarding_page.dart';
import '../features/auth/pages/splash_page.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/main_shell.dart';
import 'widgets/lifecycle_privacy_shield.dart';

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

  @override
  void initState() {
    super.initState();
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
    _appState.startAutomaticSync(
      Connectivity().onConnectivityChanged.map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      ),
    );
    if (startingFlow != AppFlowStep.splash) _appState.bootstrap();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: _appState,
      child: MaterialApp(
        title: 'Vesper Finance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) =>
            LifecyclePrivacyShield(child: child ?? const SizedBox.shrink()),
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
    );
  }
}

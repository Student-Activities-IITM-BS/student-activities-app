import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:student_activities/core/app_preferences.dart';
import 'package:student_activities/core/theme.dart';
import 'package:student_activities/services/app_link_service.dart';
import 'package:student_activities/services/auth_service.dart';
import 'package:student_activities/screens/auth/login_screen.dart';
import 'package:student_activities/screens/main_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  unawaited(AppLinkService.instance.initialize());

  runApp(const StudentActivitiesApp());
}

class StudentActivitiesApp extends StatelessWidget {
  const StudentActivitiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) => MaterialApp(
        title: 'Student Activities',
        navigatorKey: AuthService.instance.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(
          AppPreferences.instance.visualStyle,
          predictiveBack: AppPreferences.instance.predictiveBack,
        ),
        darkTheme: AppTheme.darkThemeFor(
          AppPreferences.instance.visualStyle,
          predictiveBack: AppPreferences.instance.predictiveBack,
        ),
        themeMode: AppPreferences.instance.themeMode,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const SplashScreen(),
        ),
        builder: (context, child) =>
            _SystemInsetSurface(child: child ?? const SizedBox.shrink()),
        home: const SplashScreen(),
      ),
    );
  }
}

class _SystemInsetSurface extends StatelessWidget {
  const _SystemInsetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconBrightness = Theme.of(context).brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        systemNavigationBarIconBrightness: iconBrightness,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
      child: ColoredBox(
        color: scheme.surface,
        child: SafeArea(top: false, bottom: true, child: child),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await AppPreferences.instance.load();
    final restored = await AuthService.instance.tryRestoreSession();
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) =>
            restored ? const MainLayout() : const LoginScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.webp',
              width: 92,
              height: 92,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.school_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Student Activities',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'IIT Madras BS',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

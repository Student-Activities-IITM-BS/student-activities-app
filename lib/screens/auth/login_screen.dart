import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:student_activities/screens/main_layout.dart';
import 'package:student_activities/services/auth_service.dart';
import 'package:student_activities/widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _webAuthSubscription;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webAuthSubscription = GoogleSignIn.instance.authenticationEvents.listen(
        _handleWebAuthentication,
        onError: _handleWebAuthenticationError,
      );
      unawaited(_initializeWebSignIn());
    }
  }

  Future<void> _initializeWebSignIn() async {
    try {
      await AuthService.instance.initializeGoogleSignIn();
    } catch (error) {
      _handleWebAuthenticationError(error);
    }
  }

  Future<void> _handleWebAuthentication(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (!mounted ||
        event is! GoogleSignInAuthenticationEventSignIn ||
        _loading) {
      return;
    }
    setState(() => _loading = true);
    final result = await AuthService.instance.completeGoogleSignIn(event.user);
    if (!mounted) return;
    setState(() => _loading = false);
    _finishSignIn(result);
  }

  void _handleWebAuthenticationError(Object error) {
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AuthService.instance.signInErrorMessage(error))),
    );
  }

  @override
  void dispose() {
    _webAuthSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await AuthService.instance.signIn();
    if (!mounted) return;
    setState(() => _loading = false);
    _finishSignIn(result);
  }

  void _finishSignIn(AuthResult result) {
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Sign-in was not completed.')),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/logo.webp',
                    width: 104,
                    height: 104,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.school_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Student Activities',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'IIT Madras BS student community',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 42),
                  if (kIsWeb)
                    SizedBox(height: 48, child: buildGoogleSignInButton())
                  else
                    FilledButton.icon(
                      onPressed: _loading ? null : _signIn,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        _loading ? 'Signing in' : 'Continue with Google',
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Use your IITM student account.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

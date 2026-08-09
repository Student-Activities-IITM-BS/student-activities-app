import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_activities/core/constants.dart';
import 'package:student_activities/services/api_client.dart';
import 'package:student_activities/services/desktop_google_auth_platform.dart';
import 'package:student_activities/screens/auth/login_screen.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? _token;
  Map<String, dynamic>? _user;
  bool _isInitialized = false;
  static const _secureStorage = FlutterSecureStorage();

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get _isDesktop => !kIsWeb && (Platform.isLinux || Platform.isWindows);

  String get userName =>
      _user?['name'] ??
      _user?['email']?.toString().split('@').first ??
      'Student';
  String get userEmail => _user?['email'] ?? '';
  String? get userPicture => _user?['picture'];
  String? get studentId => _user?['studentId'];

  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    var savedToken = await _secureStorage.read(key: AppConstants.tokenKey);
    if (savedToken == null || savedToken.isEmpty) {
      final legacyToken = prefs.getString(AppConstants.tokenKey);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await _secureStorage.write(
          key: AppConstants.tokenKey,
          value: legacyToken,
        );
        await prefs.remove(AppConstants.tokenKey);
        savedToken = legacyToken;
      }
    }
    final savedUser = prefs.getString(AppConstants.userKey);

    if (savedToken != null && savedToken.isNotEmpty) {
      _token = savedToken;
      if (savedUser != null) {
        try {
          _user = jsonDecode(savedUser) as Map<String, dynamic>;
        } catch (_) {}
      }

      _validateSessionInBackground();
      return true;
    }
    return false;
  }

  Future<void> _validateSessionInBackground() async {
    try {
      final resp = await ApiClient.instance.get('/auth/me');
      if (resp.success && resp.data is Map && resp.data['user'] != null) {
        _user = Map<String, dynamic>.from(resp.data['user'] as Map);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.userKey, jsonEncode(_user));
      } else {
        if (resp.statusCode == 401 || resp.statusCode == 403) {
          await signOut();
          final navState = navigatorKey.currentState;
          if (navState != null) {
            navState.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _ensureInitialized() async {
    if (_isDesktop) return;
    if (_isInitialized) return;
    final clientId = AppConstants.googleClientId.trim();
    if (clientId.isEmpty) {
      throw StateError('Google Sign-In is not configured for this build.');
    }
    final isAndroid = !kIsWeb && Platform.isAndroid;
    await GoogleSignIn.instance.initialize(
      clientId: isAndroid ? null : clientId,
      serverClientId: kIsWeb ? null : clientId,
    );
    _isInitialized = true;
  }

  Future<void> initializeGoogleSignIn() => _ensureInitialized();

  Future<AuthResult> signIn() async {
    try {
      if (_isDesktop) {
        final clientId = AppConstants.googleDesktopClientId.trim();
        if (clientId.isEmpty) {
          throw StateError(
            'Google desktop sign-in is not configured for this build.',
          );
        }
        final clientSecret = AppConstants.googleDesktopClientSecret.trim();
        if (clientSecret.isEmpty) {
          throw StateError(
            'Google desktop client secret is not configured for this build.',
          );
        }
        final credential = await authenticateDesktopGoogle(
          clientId,
          clientSecret: clientSecret,
        );
        return _completeGoogleCredential(
          idToken: credential.idToken,
          email: credential.email,
          displayName: credential.displayName,
          photoUrl: credential.photoUrl,
        );
      }
      await _ensureInitialized();
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate(scopeHint: ['email', 'profile']);

      return completeGoogleSignIn(account);
    } catch (e) {
      return _signInError(e);
    }
  }

  Future<AuthResult> completeGoogleSignIn(GoogleSignInAccount account) async {
    final auth = account.authentication;
    return _completeGoogleCredential(
      idToken: auth.idToken,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
      signOutGoogle: true,
    );
  }

  Future<AuthResult> _completeGoogleCredential({
    required String? idToken,
    required String email,
    String? displayName,
    String? photoUrl,
    bool signOutGoogle = false,
  }) async {
    try {
      final emailDomain = email.split('@').last.toLowerCase();
      if (!AppConstants.allowedDomains.contains(emailDomain)) {
        if (signOutGoogle) await GoogleSignIn.instance.signOut();
        return AuthResult(
          success: false,
          error:
              'Only IITM student emails are allowed.\nAllowed domains: ${AppConstants.allowedDomains.join(", ")}',
        );
      }

      if (idToken == null || idToken.isEmpty) {
        if (signOutGoogle) await GoogleSignIn.instance.signOut();
        return AuthResult(
          success: false,
          error: 'Failed to get authentication token',
        );
      }

      final resp = await ApiClient.instance.postUnauth(
        '/auth/google',
        body: {'idToken': idToken},
      );

      if (!resp.success) {
        if (signOutGoogle) await GoogleSignIn.instance.signOut();
        return AuthResult(
          success: false,
          error: resp.error ?? 'Backend authentication failed',
        );
      }

      final data = resp.data as Map<String, dynamic>;
      final backendToken = data['token'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (backendToken == null || backendToken.isEmpty) {
        if (signOutGoogle) await GoogleSignIn.instance.signOut();
        return AuthResult(
          success: false,
          error: 'No token received from server',
        );
      }

      _token = backendToken;
      _user =
          userData ??
          {'email': email, 'name': displayName, 'picture': photoUrl};

      final prefs = await SharedPreferences.getInstance();
      await _secureStorage.write(
        key: AppConstants.tokenKey,
        value: backendToken,
      );
      await prefs.setString(AppConstants.userKey, jsonEncode(_user));

      return AuthResult(success: true);
    } catch (e) {
      return _signInError(e);
    }
  }

  AuthResult _signInError(Object error) {
    debugPrint('[AuthService] Sign-in error: $error');

    String userFriendlyMessage = 'Google Sign-In failed. Please try again.';
    final errStr = error.toString().toLowerCase();

    if (errStr.contains('canceled') ||
        errStr.contains('cancelled') ||
        errStr.contains('sign_in_canceled')) {
      userFriendlyMessage = 'Sign-in was cancelled.';
    } else if (errStr.contains('network') || errStr.contains('connection')) {
      userFriendlyMessage =
          'Network error. Please check your internet connection.';
    } else if (errStr.contains('unimplemented') ||
        errStr.contains('unsupported') ||
        errStr.contains('desktop sign-in is not configured') ||
        errStr.contains('desktop client secret is not configured')) {
      userFriendlyMessage =
          'Google Sign-In is not configured for this desktop build.';
    } else if (errStr.contains('client_secret')) {
      userFriendlyMessage =
          'The desktop Google OAuth client secret is missing or invalid.';
    } else if (errStr.contains('clientconfigurationerror') ||
        errStr.contains('configuration')) {
      userFriendlyMessage =
          'Client configuration error. Please contact the administrator.';
    } else if (errStr.contains('developer_error') ||
        errStr.contains('developererror')) {
      userFriendlyMessage =
          'Developer configuration error. Please verify the application setup.';
    }

    return AuthResult(success: false, error: userFriendlyMessage);
  }

  String signInErrorMessage(Object error) =>
      _signInError(error).error ?? 'Google Sign-In failed. Please try again.';

  Future<void> signOut() async {
    try {
      await ApiClient.instance.post('/auth/logout');
    } catch (_) {}

    if (!_isDesktop) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }

    await _clearSession();
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
  }
}

class AuthResult {
  final bool success;
  final String? error;
  AuthResult({required this.success, this.error});
}

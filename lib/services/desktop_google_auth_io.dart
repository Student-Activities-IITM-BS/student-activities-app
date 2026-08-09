import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DesktopGoogleCredential {
  final String idToken;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const DesktopGoogleCredential({
    required this.idToken,
    required this.email,
    this.displayName,
    this.photoUrl,
  });
}

class DesktopGoogleAuthException implements Exception {
  final String message;

  const DesktopGoogleAuthException(this.message);

  @override
  String toString() => message;
}

Future<DesktopGoogleCredential> authenticateDesktopGoogle(
  String clientId, {
  required String clientSecret,
}) async {
  if (clientId.trim().isEmpty) {
    throw StateError(
      'Google desktop sign-in is not configured for this build.',
    );
  }

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final state = _randomToken();
  final verifier = _randomToken(48);
  final challenge = _base64UrlNoPadding(
    sha256.convert(utf8.encode(verifier)).bytes,
  );
  final redirectUri = Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.host,
    port: server.port,
    path: '/oauth2redirect',
  );

  final authorizationUri =
      Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri.toString(),
        'response_type': 'code',
        'scope': 'openid email profile',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'select_account',
      });

  try {
    final launched = await launchUrl(
      authorizationUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw const DesktopGoogleAuthException(
        'Could not open the system browser for Google Sign-In.',
      );
    }

    final callback = await _waitForCallback(server);
    final callbackParams = callback.queryParameters;
    if (callbackParams['state'] != state) {
      throw const DesktopGoogleAuthException(
        'Google Sign-In returned an invalid response.',
      );
    }
    final error = callbackParams['error'];
    if (error != null) {
      if (error == 'access_denied') {
        throw const DesktopGoogleAuthException('Sign-in was cancelled.');
      }
      throw DesktopGoogleAuthException(
        callbackParams['error_description'] ?? 'Google Sign-In failed.',
      );
    }

    final code = callbackParams['code'];
    if (code == null || code.isEmpty) {
      throw const DesktopGoogleAuthException(
        'Google did not return an authorization code.',
      );
    }

    final tokenResponse = await http.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      headers: {'Accept': 'application/json'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri.toString(),
      },
    );
    final tokenData = _decodeJson(tokenResponse.body);
    if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
      throw DesktopGoogleAuthException(
        tokenData['error_description']?.toString() ??
            tokenData['error']?.toString() ??
            'Google token exchange failed.',
      );
    }

    final idToken = tokenData['id_token']?.toString();
    if (idToken == null || idToken.isEmpty) {
      throw const DesktopGoogleAuthException(
        'Google did not return an ID token.',
      );
    }
    final claims = _decodeJwtPayload(idToken);
    final email = claims['email']?.toString();
    if (email == null || email.isEmpty) {
      throw const DesktopGoogleAuthException(
        'Google did not return an email address.',
      );
    }

    return DesktopGoogleCredential(
      idToken: idToken,
      email: email,
      displayName: claims['name']?.toString(),
      photoUrl: claims['picture']?.toString(),
    );
  } finally {
    await server.close(force: true);
  }
}

Future<Uri> _waitForCallback(HttpServer server) async {
  final completer = Completer<Uri>();
  late final StreamSubscription<HttpRequest> subscription;
  subscription = server.listen((request) async {
    if (request.uri.path != '/oauth2redirect') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(
        '<!doctype html><meta charset="utf-8"><title>Student Activities</title>'
        '<p>You can return to Student Activities. This window can be closed.</p>',
      );
    await request.response.close();
    if (!completer.isCompleted) {
      completer.complete(request.uri);
    }
  });

  try {
    return await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => throw const DesktopGoogleAuthException(
        'Google Sign-In timed out. Please try again.',
      ),
    );
  } finally {
    await subscription.cancel();
  }
}

Map<String, dynamic> _decodeJson(String value) {
  final decoded = jsonDecode(value);
  return decoded is Map<String, dynamic>
      ? decoded
      : Map<String, dynamic>.from(decoded as Map);
}

Map<String, dynamic> _decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length < 2) {
    throw const DesktopGoogleAuthException(
      'Google returned an invalid ID token.',
    );
  }
  final decoded = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
  );
  if (decoded is! Map) {
    throw const DesktopGoogleAuthException(
      'Google returned an invalid ID token.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _randomToken([int length = 32]) {
  final random = Random.secure();
  final bytes = List<int>.generate(length, (_) => random.nextInt(256));
  return _base64UrlNoPadding(bytes);
}

String _base64UrlNoPadding(List<int> bytes) =>
    base64UrlEncode(bytes).replaceAll('=', '');

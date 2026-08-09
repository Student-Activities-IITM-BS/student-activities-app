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

Future<DesktopGoogleCredential> authenticateDesktopGoogle(
  String clientId, {
  required String clientSecret,
}) {
  throw UnsupportedError(
    'Desktop Google Sign-In is unavailable on this platform.',
  );
}

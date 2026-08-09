class AppConstants {
  AppConstants._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.iitmbs.org',
  );
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );
  static const String googleDesktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
  );
  static const String googleDesktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
  );

  static const List<String> allowedDomains = [
    'study.iitm.ac.in',
    'ds.study.iitm.ac.in',
    'es.study.iitm.ac.in',
    'ae.study.iitm.ac.in',
    'mg.study.iitm.ac.in',
  ];

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}

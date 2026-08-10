import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class AppLinkService {
  AppLinkService._();

  static final instance = AppLinkService._();

  final ValueNotifier<Uri?> latestLink = ValueNotifier<Uri?>(null);
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  String? _lastLink;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _subscription = _appLinks.uriLinkStream.listen(
      _publish,
      onError: (_, _) {},
    );
    try {
      _publish(await _appLinks.getInitialLink());
    } catch (_) {}
  }

  void _publish(Uri? uri) {
    if (uri == null || uri.toString() == _lastLink) return;
    _lastLink = uri.toString();
    latestLink.value = uri;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}

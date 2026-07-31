import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget buildGoogleSignInButton() {
  return LayoutBuilder(
    builder: (_, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth.clamp(220.0, 400.0).toDouble()
          : 400.0;
      return google_web.renderButton(
        configuration: google_web.GSIButtonConfiguration(
          type: google_web.GSIButtonType.standard,
          theme: google_web.GSIButtonTheme.outline,
          size: google_web.GSIButtonSize.large,
          text: google_web.GSIButtonText.continueWith,
          shape: google_web.GSIButtonShape.pill,
          logoAlignment: google_web.GSIButtonLogoAlignment.left,
          minimumWidth: width,
          locale: 'en',
        ),
      );
    },
  );
}

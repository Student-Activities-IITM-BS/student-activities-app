import 'package:flutter/material.dart';

import 'google_sign_in_button_stub.dart'
    if (dart.library.html) 'google_sign_in_button_web.dart'
    as implementation;

Widget buildGoogleSignInButton() => implementation.buildGoogleSignInButton();

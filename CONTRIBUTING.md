# Contributing

Student Activities is a student-led SEC WebOps project. Contributions from students, alumni, and other community members are welcome. The canonical source repository is [Student-Activities-IITM-BS/student-activities-app](https://github.com/Student-Activities-IITM-BS/student-activities-app).

## Before You Start

1. Install Flutter 3.44.4 or a compatible stable release.
2. Copy `config/app.example.json` to `config/app.json`.
3. Add a Google OAuth client ID if you need to exercise sign-in locally.
4. Run `flutter pub get`.

The local configuration file is ignored by Git. Never commit service-account keys, signing keys, tokens, or other private credentials.

## Development Checks

Run these before opening a pull request:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --no-wasm-dry-run
flutter build apk --debug
```

## Pull Requests

- Keep the change focused and explain the user-facing effect.
- Follow the existing Material/UIX theme and platform conventions.
- Add or update tests for changed behavior.
- Do not commit generated build output or local configuration.
- Include screenshots for visible UI changes when practical.

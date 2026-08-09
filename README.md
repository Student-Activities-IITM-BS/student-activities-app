<div align="center">
  <img src="assets/logo.webp" alt="Student Activities logo" width="128">
  <h1>Student Activities</h1>
  <p>A calm, native home for the IIT Madras BS community.</p>
  <p>
    <a href="https://iitmbs.org">Website</a>
    &nbsp;&middot;&nbsp;
    <a href="https://github.com/Student-Activities-IITM-BS/student-activities-app">Source</a>
    &nbsp;&middot;&nbsp;
    <a href="https://iitmbs.org/privacy">Privacy</a>
    &nbsp;&middot;&nbsp;
    <a href="CONTRIBUTING.md">Contributing</a>
  </p>
  <p>
    <img src="https://img.shields.io/badge/Flutter-3.44.4-54C5F8?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter 3.44.4">
    <img src="https://img.shields.io/badge/Android%20%7C%20iOS%20%7C%20Desktop-supported-2E7D32?style=for-the-badge" alt="Supported platforms">
    <img src="https://img.shields.io/badge/SEC%20WebOps-student%20led-263238?style=for-the-badge" alt="SEC WebOps">
  </p>
</div>

Student Activities brings campus updates, houses and societies, Voices, recruitment, events, profiles, and student services into one cohesive experience. It is maintained through SEC WebOps and is being built to welcome more student contributors over time.

## Features

- **Home and updates** for announcements, notices, and community news.
- **Houses and societies** with people, links, galleries, and activities.
- **Voices** for anonymous discussions, replies, and live chat.
- **Academic assistant** for questions about courses, exams, policies, and assessments.
- **Calendar, recruitment, elections, and budget** views in one app.
- **Material and UIX themes** with system-aware dark mode and navigation customization.
- **Deep links** from `iitmbs.org` and the `iitmbs://` scheme into native screens.
- **Flutter web target (WIP)** for future browser support. The existing web frontend is available at [iitmbs.org](https://iitmbs.org).

## Platform Support

| Target  | Development               | Release artifact                                                  |
| ------- | ------------------------- | ----------------------------------------------------------------- |
| Android | `flutter run -d <device>` | APK and AAB                                                       |
| iOS     | `flutter run -d <device>` | Unsigned IPA in CI; signing is handled by the release environment |
| Web     | `flutter run -d chrome`   | WIP, not currently supported                                     |
| Linux   | `flutter run -d linux`    | AppImage, DEB, RPM, and tar.gz                                   |
| Windows | `flutter run -d windows`  | Installer EXE, portable EXE, and ZIP                             |
| macOS   | `flutter run -d macos`    | App bundle                                                        |

The Flutter web target is currently a work in progress and is not a supported web app. Use the existing frontend at [iitmbs.org](https://iitmbs.org) for browser access.

## Development

Install Flutter 3.44.4 or a compatible stable release. Then create a local build configuration:

```sh
cp config/app.example.json config/app.json
```

Set `GOOGLE_CLIENT_ID` and, for Linux or Windows, `GOOGLE_DESKTOP_CLIENT_ID` plus `GOOGLE_DESKTOP_CLIENT_SECRET` in `config/app.json`, then run:

```sh
flutter pub get
flutter run --dart-define-from-file=config/app.json
```

The Android application ID is `org.iitmbs.sa`. The backend defaults to `https://api.iitmbs.org`, but `API_BASE_URL` can be overridden in the same config file for a development or staging environment.

### Google Sign-In configuration

`GOOGLE_CLIENT_ID`, `GOOGLE_DESKTOP_CLIENT_ID`, and `GOOGLE_DESKTOP_CLIENT_SECRET` are supplied at build time with `--dart-define-from-file` and are intentionally absent from tracked Dart source. Android and web use the existing client; Linux and Windows use a Google OAuth client whose application type is **Desktop app**. The desktop flow opens the system browser and returns through a temporary loopback address. Google treats desktop client secrets as public credentials because they cannot be protected inside distributed applications, but service-account keys and backend secrets must never be put in this app. Security comes from the Google Cloud application restrictions, Android signing certificate restrictions, authorized web origins, and backend token validation.

Create the desktop client in the same Google Cloud project as the existing web and Android clients. Add its ID and generated secret to `GOOGLE_DESKTOP_CLIENT_ID` and `GOOGLE_DESKTOP_CLIENT_SECRET`. Configure the backend with the same `GOOGLE_DESKTOP_CLIENT_ID` so it accepts desktop ID-token audiences. The OAuth consent screen must be configured and either published or limited to accounts listed as test users.

For a build without Google Sign-In configuration, the app still compiles, but sign-in reports a configuration error instead of using a source-controlled value.

## Checks

Run the same checks locally that are required by CI:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --no-wasm-dry-run
flutter build apk --debug
```

For a reproducible native Linux build, use the included Nix shell:

```sh
nix-shell --run 'flutter build linux --release'
```

Pull requests run analysis, tests, a web build, and an Android debug build. Version tags trigger the release workflow described in [docs/releasing.md](docs/releasing.md).

## Project Layout

```text
lib/core/                 shared configuration, theme, widgets, markdown
lib/models/               API response models
lib/screens/              feature screens and navigation
lib/services/             API, auth, app links, and live chat
config/app.example.json   local build configuration template
android/ ios/ web/ ...    platform runners and metadata
```

The app uses Dio for HTTP APIs, Socket.IO for Voices live chat, `gpt_markdown` for rendered Markdown, and `url_launcher` for external links.

## Contributing

Student Activities is intended to grow with the SEC WebOps community. Start with [CONTRIBUTING.md](CONTRIBUTING.md), keep changes focused, and include tests for behavior that crosses screens or services.

## Privacy

Read the current policy at [iitmbs.org/privacy](https://iitmbs.org/privacy). Session credentials are stored through the platform secure-storage implementation, and the app does not contain server-side secrets.

## License

Student Activities is released under the [Apache License 2.0](LICENSE).

```text
   Copyright 2026 SEC WebOps

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```

## Maintainers

The project is currently led by SEC WebOps, with [Abhi](https://github.com/AbhiTheModder) as the current primary developer.

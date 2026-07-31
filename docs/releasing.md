# Releasing

Releases are created by `.github/workflows/release.yml` in the [Student-Activities-IITM-BS/student-activities-app](https://github.com/Student-Activities-IITM-BS/student-activities-app) repository from a semantic version tag such as `v1.1.0`. The workflow builds Android, iOS, the WIP Flutter web target, Linux packages, and Windows packages, then attaches them to a GitHub release.

## Repository Configuration

Configure these GitHub Actions values before using the release workflow:

- `GOOGLE_CLIENT_ID` secret: the Google OAuth client ID used by the app.
- `API_BASE_URL` variable: optional; defaults to `https://api.iitmbs.org`.
- `ANDROID_KEYSTORE_FILE` secret: base64-encoded release keystore.
- `ANDROID_KEYSTORE_PASSWORD` secret.
- `ANDROID_KEY_PASSWORD` secret.
- `ANDROID_KEY_ALIAS` secret.

The Google client ID is not a private credential, but keeping it in Actions configuration prevents source drift and lets each build environment provide its own OAuth client. The Android keystore values are private and must never be committed.

## Release Steps

1. Update the version in `pubspec.yaml` when needed.
2. Run the local checks from the README.
3. Push a tag such as `v1.1.0`.
4. Review the generated artifacts and release notes in GitHub.

The Android job produces split APKs, a universal APK, and an AAB. The Linux job produces a tar.gz bundle, AppImage, DEB, and RPM. The Windows job produces a ZIP, portable EXE, and Inno Setup installer EXE. The Linux build requires the `libsecret-1-dev` system package for secure storage. The iOS job creates an unsigned IPA; App Store signing should happen in the organization’s macOS signing environment.

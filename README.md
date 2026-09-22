# karaterating_trainer

## Project Documentation

- [Project guide: backend and Flutter code map](../karaterating-v2/docs/project-guide.md)
- [Remaining scope: mobile trainer and web panel](../karaterating-v2/docs/remaining-scope.md)

## Android APK Against the Server

```bash
flutter build apk --release --build-number=20260918 \
  --dart-define=API_BASE_URL=https://karate-rating.ru/api/mobile
```

The universal APK is written to `build/app/outputs/flutter-apk/app-release.apk`.
Use a higher build number for the next distributed build. The application ID and
secure-storage keys stay unchanged. `API_BASE_URL` includes `/api/mobile`; without
this build-time setting the development default is localhost.

This is a release-mode APK for direct testing, signed with the existing local
Android debug key, not a store release. Production store signing must be configured
separately. Keep the key stable to update previously installed test builds.

After switching from integration/debug builds, allow Flutter's normal plugin
regeneration: do not add `--no-pub` to this command. Otherwise a stale
`GeneratedPluginRegistrant` can reference the release-excluded `integration_test`
plugin. Do not edit the generated Java file manually.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

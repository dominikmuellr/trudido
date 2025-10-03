# Trudido — Flutter Todo App

Lightweight, privacy-first todo application built with Flutter.

This repository contains the app source. The public README below gives contributors and users the quick steps to run the app and add screenshots or documentation.

---

## Features

- Task creation, editing and completion
- Categories/folders and templates
- Local persistence (no remote server required)
- Light / Dark theme support with dynamic color schemes
- Notification prompts and system permission helpers

## Screenshots

<p align="center">
  <img src="screenshots/1.png" alt="screenshot 1" width="300"/>
  <img src="screenshots/2.png" alt="screenshot 2" width="300"/>
  <img src="screenshots/3.png" alt="screenshot 3" width="300"/>
  <img src="screenshots/4.png" alt="screenshot 4" width="300"/>
  <img src="screenshots/5.png" alt="screenshot 5" width="300"/>
  <img src="screenshots/6.png" alt="screenshot 6" width="300"/>
  <img src="screenshots/7.png" alt="screenshot 7" width="300"/>
  <img src="screenshots/8.png" alt="screenshot 8" width="300"/>
  <img src="screenshots/9.png" alt="screenshot 9" width="300"/>
  <img src="screenshots/10.png" alt="screenshot 10" width="300"/>
</p>


---

## Requirements

- Flutter SDK (stable channel)
- Android SDK or Xcode for mobile platforms
- Recommended: Android Studio or VS Code with Flutter & Dart plugins

## Getting started (developer)

1. Install Flutter: https://flutter.dev/docs/get-started/install
2. From the project root run:

```powershell
flutter pub get
```

3. Run the app on a connected device or emulator:

```powershell
flutter run -d <device-id>
```

4. Build an APK (Android):

```powershell
flutter build apk --release
```

Notes

- If you deleted platform folders for a trimmed repo, re-run `flutter create .` to recreate platform scaffolding if needed.
- If Android Studio shows unresolved symbols after cleanup, try: File → Invalidate Caches / Restart, then run `flutter pub get`.

## Tests

Run static analysis:

```powershell
dart analyze
```

Run unit/widget tests (if present):

```powershell
flutter test
```

## Sensitive files / excluded items

This repository intentionally excludes machine-specific or secret files. Do NOT commit the following items:

- `android/local.properties` (SDK path)
- Keystore files: `*.jks`, `*.keystore`, `key.properties`
- Service credentials: `google-services.json`, `GoogleService-Info.plist`
- Environment files: `.env`
- Build artifacts: `/build`, `*.apk`, `*.aab`, `/coverage`

The project `.gitignore` already contains rules to ignore those files. Internal notes were moved to `docs/internal/`.

## Contributing

1. Fork and create a feature branch.
2. Open a PR describing the change.

If you submit screenshots, add them under `docs/images/` and reference them in this README.

## License

Add your license information here (e.g., MIT) or create a `LICENSE` file.

---

If you want, tell me which screenshots you'd like included and I can add placeholder files to `docs/images/` and update the README image paths for you.

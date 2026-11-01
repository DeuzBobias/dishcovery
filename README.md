# Dishcovery Android

Dishcovery is an Android application written in Dart with Flutter. The application entry point is `app/lib/main.dart`; Android integration is in `app/android`. Open `app/` in VS Code with the Flutter extension.

## Install on your phone

Copy `deliverables/Dishcovery-Android.apk` to a 64-bit ARM Android phone and open it to install. Android may ask you to allow installation from the app used to open the APK. This is a presentation release signed with a development key, not a Play Store release. Keep the same signing key for future updates.

## Build

Run `./build-and-run.ps1` to create the APK. Use `./build-and-run.ps1 -Install` or `Launch Dishcovery.cmd` with a USB-debugging Android device connected to build, install and launch it. The local Flutter SDK is in `.tools/flutter`; the Android SDK location is configured in `app/android/local.properties`.

From `app/`, run `../.tools/flutter/bin/flutter.bat analyze` and `../.tools/flutter/bin/flutter.bat test`. Set PUB_CACHE to the project `.tools/pub-cache` directory when using the bundled SDK.

## Features

- Fifteen built-in recipes with cooking instructions, per-ingredient calories, serving nutrition and price estimates.
- Recipe creation, editing, local photos, bookmarks, notes, local activity and an offline rule-based assistant.
- Smart Pantry name matching with missing ingredient lists and specific handling for olive/sesame oils.
- Peso budgets, serving scaling, optional pantry deductions, price overrides and visible retail reference links. Costs describe quantities used, not whole-package shopping bills. Prices are estimates, not live market prices.
- Optional age, height and weight plus Fitness, Recipes or Community preferences.
- Daily food log with manual or recipe entries, fractional portions, editable entries, removal/restoration, date selection and user-set calorie/macro targets.
- Optional personalized calorie plans for Fitness users, with estimated maintenance, daily food targets, dated plan history and completed-day estimated balances. See `deliverables/Flutter-Verification.md` for the calculation and limitations.
- Native Documents file export/import for backups. User records are stored in account-scoped SQLite storage and sync through Supabase.

## Android integration

Flutter renders the interface directly. A Kotlin MethodChannel connects Android ACTION_SEND sharing, ACTION_VIEW reference links, AlarmManager reminders and NotificationManager channels. Android 13+ notification permission is requested when starting a cooking reminder. The file_picker plugin connects image and backup file selection to native Android pickers.

One cooking reminder is active at a time. The deadline is saved and recovered when reopening the matching recipe. Reminders use an inexact Android alarm and may be delayed by battery restrictions; they do not survive reboot or force-stop. Test permission denial, background delivery and resume on your phone before relying on reminders.

## Scope and verification

The APK build and Flutter automated tests are checked locally. Physical-device installation and native share, file-picker and notification behavior still require phone testing. Supabase provides email/password authentication and private account synchronization. SQLite provides local persistence. The community feed and assistant remain local features; no public multiuser community or remote AI service is implemented. Older architecture and video documents describe earlier builds; see supabase/README.md for the current setup.

Nutrition is illustrative or creator-entered. Ingredient edits require reviewing nutrition; swaps do not recalculate automatically. Built-in source references are dated 15 October 2026 and remaining costs are explicitly planning allowances.

Source design materials remain in `Temporary UI`, `Dishcovery.docx` and `Dishcovery-UserManual.pdf`. Asset attribution is in `app/assets/ATTRIBUTION.md`.

Verification: flutter analyze reports no issues and all 29 Flutter tests pass. The release APK is built for arm64-v8a.


## Interface restoration

The Android interface uses the recovered original DM Sans and Lobster fonts, original photography, logo and welcome artwork. It restores the local signup/login screens, six-step preferences wizard, Home / Recipes / Create / Activity / Profile navigation, food and people search, local follows, personal-data/photo editing, two-stage recipe editor, draft persistence, ordered instructions and per-step timers. Page transitions use the original 220 ms duration and primary button presses use a 150 ms scale animation.

Accounts now use Supabase authentication with email confirmation. Sessions are stored through Android secure storage. Earlier local credentials are not cloud accounts. Create a cloud account, then use Account & cloud sync to import earlier device data if needed.

Reference screenshots for the restored phone interface are in `app/test/goldens/restored-*.png`. Android system dialogs, sharing and notification permission prompts use the platform UI. The browser prototype remains a comparison reference, not part of the APK.

## Setup on another computer

Install Flutter (Dart is included) and Android Studio with the Android SDK. Clone this repository and open `app` in VS Code or Android Studio. From `app`, run:

```sh
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/supabase.json
```

Connect an Android phone with USB debugging or start an Android emulator before `flutter run`. To create an installer, run `flutter build apk --release --target-platform android-arm64 --dart-define-from-file=config/supabase.json`. Flutter generates machine-specific Android SDK paths locally. The `.tools` SDK and package caches used by the original Windows build scripts are not required when Flutter is installed on PATH. Release signing currently uses the development signing configuration for presentation builds; no private signing keys are included.


## Cloud setup and current release

Version 1.1.0 (build 3) adds Supabase account sync, SQLite persistence, custom allergies, and local Android notification controls. The original fonts, imagery and navigation remain. See [Supabase setup](supabase/README.md) and the SQL migration in `supabase/migrations`. The checked-in configuration contains the public publishable key only, not an administrator credential.

The project connection and denial of anonymous kitchen reads have been verified. Cross-device authenticated sync and Android permissions still require signed-in physical-device testing. All 29 Flutter tests and static analysis pass.

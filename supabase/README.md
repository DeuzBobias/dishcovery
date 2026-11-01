# Supabase and SQLite setup

The Android app now uses Supabase email/password authentication. Email confirmation is enabled on the configured project. After signup, confirm the email, then return to the app and log in. Earlier local passwords are not cloud accounts; create a Supabase account first.

## Database

Run `supabase/migrations/202611010001_kitchens.sql` in the project's SQL Editor. The script creates an account-owned kitchen table, row-level read isolation and a version-checked write function. No service-role key belongs in the app. The configuration file contains only the publishable client key.

## Build

Install Flutter and the Android SDK. From `app`:

```
flutter pub get
flutter run --dart-define-from-file=config/supabase.json
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=config/supabase.json
```

The repository's `build-and-run.ps1` passes this configuration automatically. Keep the APK signing key stable when updating existing installations. The current signing configuration is still a development key; production distribution requires your release signing setup.

## Storage and sync

SQLite stores account-scoped JSON records, including kitchen data and recipe drafts. SharedPreferences is read only for migration of earlier kitchen data; Supabase sessions use Android secure storage. SQLite itself is not encrypted. Android system backups are disabled to avoid restoring encrypted tokens without their device key.

Saves are local first, followed by a debounced cloud upload. Opening the app and Sync now also attempt synchronization. Offline changes stay pending. Each server update checks a revision number. Conflicting whole-kitchen edits require a choice in Profile → Account & cloud sync; the app never silently merges conflicting devices. Export a backup before selecting a copy. Photo data embedded in recipes/profile is included; cooking timer deadlines and notification permissions are device-local. There is no background push notification server.

Earlier data is preserved in a separate SQLite migration scope. After signing in, Profile → Account & cloud sync → Import earlier device data explicitly copies the earlier kitchen. The prior local account credentials are not uploaded.

Manual allergies are available in onboarding and cooking preferences. Case-insensitive matching checks declared allergens and ingredient words. It does not certify food safety or detect hidden allergens/cross-contact.

Settings provides notification permission controls and a test notification. Recipe activity produces local Android notifications when enabled and permitted. Cooking reminders still use inexact Android alarms and can be delayed by battery restrictions.

## Device acceptance checks

1. Create two real accounts, confirm their emails, and verify incorrect-password errors.
2. Save a recipe and allergy in account A; sign out and verify account B cannot see them.
3. Sign in as A on a second device and sync. Verify recipes, photos, logs and preferences.
4. Edit offline, restart, reconnect and sync. Make separate edits on both devices and check conflict handling.
5. Deny notification permission, then allow it in Android Settings and send a test notification.
6. Confirm backup/restore, earlier-data import, recipe timers and manual allergy warnings.

The community feed remains sample content with local interactions; Supabase integration here is private account synchronization, not a public community service.

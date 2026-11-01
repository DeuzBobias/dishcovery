# Release verification 1 November 2026

Version: 1.1.0, build 3. Flutter Android arm64 release.

Implemented: Supabase email/password authentication and secure session persistence; account-scoped SQLite kitchen/draft storage; local-first cloud sync with revision conflict detection; explicit import of earlier device data; custom allergy entry and matching; Android notification controls and feedback messages. Presentation-mode and local-account UI labels were removed.

Validation: Flutter analysis has no issues; all 29 tests pass. Tests cover account isolation, protection of pending edits from cloud downloads, sync acknowledgements, draft deletion, legacy-data preservation, custom allergy matching and existing recipe/tracker/onboarding flows.

Live project check: public key accepted by Auth; email signup enabled and email confirmation required. The kitchen table exists and anonymous SELECT requests are denied. The configured project is rjinxrhgkzzvxcnhybmq. No administrator key is stored in this repository.

Not yet verified: authenticated sync between two physical Android devices, permission dialogs and background reminder delivery on a phone. Create a real account, confirm its email, sign in and use Profile → Account & cloud sync to test. Earlier device-only passwords do not authenticate with Supabase.

The app still uses the existing development signing configuration. Public app-store distribution requires release signing. Community content remains sample data; this release provides private account sync rather than a public social backend.

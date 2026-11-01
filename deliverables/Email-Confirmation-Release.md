# Dishcovery 1.1.1 (4): Android email confirmation

The Android app registers `com.dishcovery.dishcovery://login-callback/`.
Signup and resend requests explicitly use this callback. Supabase's Site URL
and allowed redirect URL were set to the same address on November 1, 2026.
Email confirmation is enabled; Gmail custom SMTP delivery was received by
the user during the earlier delivery test.

Supabase verifies the confirmation link before redirecting to Android.
Dishcovery opens the existing password-login screen. Incoming links never
sign a user in, import URL tokens, or replace an existing account. Password
login checks the account's confirmed status with Supabase. This also lets
people confirm on a different device and then sign in on their phone.

Expired/already-used callback errors show feedback. The login screen offers
resending after a pending signup, confirmation callback, or unconfirmed-login
error. No SMTP credentials are included in the source or APK.

## Phone acceptance check

1. Install the new APK over the existing installation.
2. Register using an email address not already registered.
3. Open the newest confirmation email on the Android phone and tap its link.
4. Allow the browser to open Dishcovery if prompted, then log in.
5. Confirm onboarding and cloud sync work as usual.

Existing accounts created while confirmation was disabled are not
retroactively forced to verify. Old emails may retain the previous redirect;
use a newly requested confirmation email. On a device without Dishcovery
installed, the custom app URL cannot launch the app. Physical-device callback
launch remains a manual acceptance check.

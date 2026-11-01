import 'package:flutter_test/flutter_test.dart';
import 'package:dishcovery/auth_callback.dart';

void main() {
  test('confirmation callback opens login without claiming authentication', () {
    expect(
      confirmationMessage(Uri.parse('$confirmationRedirect?code=test')),
      'Back from email confirmation. Sign in to continue.',
    );
  });
  test('unrelated links are ignored', () {
    for (final value in [
      'https://example.com/',
      'com.dishcovery.dishcovery://other/',
      '${confirmationRedirect}other',
    ]) {
      expect(confirmationMessage(Uri.parse(value)), isNull);
    }
  });
  test(
    'expired links show actionable feedback for query and fragment errors',
    () {
      for (final suffix in [
        '?error=access_denied',
        '#error_code=otp_expired',
      ]) {
        expect(
          confirmationMessage(Uri.parse('$confirmationRedirect$suffix')),
          contains('expired or already been used'),
        );
      }
    },
  );
}

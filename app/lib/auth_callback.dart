const confirmationRedirect = 'com.dishcovery.dishcovery://login-callback/';

/// This callback only opens login. It never authenticates a user or trusts
/// credentials from an incoming URI; password login checks Supabase state.
String? confirmationMessage(Uri uri) {
  if (uri.scheme != 'com.dishcovery.dishcovery' ||
      uri.host != 'login-callback' ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    return null;
  }
  final fragment = Uri.splitQueryString(uri.fragment);
  final params = {...uri.queryParameters, ...fragment};
  if (params.containsKey('error') || params.containsKey('error_code')) {
    return 'This confirmation link may have expired or already been used. Try signing in; if your email is still unconfirmed, request a new link.';
  }
  return 'Back from email confirmation. Sign in to continue.';
}

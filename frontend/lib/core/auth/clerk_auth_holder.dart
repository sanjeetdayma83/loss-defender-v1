import "package:clerk_flutter/clerk_flutter.dart";

/// Global accessor for the current ClerkAuthState.
/// Set once from AppRoot after ClerkAuthBuilder provides it (see app_root.dart).
///
/// NOTE: clerk_flutter is a beta/community-maintained SDK. If `isSignedIn`
/// or `sessionToken()` don't match your installed version, check
/// `ClerkAuthState` in your IDE's autocomplete and adjust ONLY this file —
/// every other file in the app talks to auth exclusively through here.
class ClerkAuthHolder {
  static ClerkAuthState? instance;

  static bool get isSignedIn {
    final s = instance;
    if (s == null) return false;
    try {
      return s.isSignedIn;
    } catch (_) {
      // Fallback for SDK versions without isSignedIn — adjust if needed.
      return false;
    }
  }

  static Future<String?> getToken() async {
    final s = instance;
    if (s == null) return null;
    try {
      final token = await s.sessionToken();
      return token.jwt;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await instance?.signOut();
    } catch (_) {
      // no-op — user still gets routed to /login by redirect logic
    }
  }
}
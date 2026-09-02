import "package:clerk_flutter/clerk_flutter.dart";

/// Global Clerk session access for Dio + router.
class ClerkAuthHolder {
  static ClerkAuthState? instance;

  static bool get isSignedIn {
    final s = instance;
    if (s == null) return false;
    try {
      return s.isSignedIn;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getToken() async {
    final s = instance;
    if (s == null) return null;
    try {
      final token = await s.sessionToken();
      final jwt = token.jwt;
      // Must be header.payload.signature — never send garbage to API
      if (jwt.isEmpty) return null;
      if (jwt.split(".").length != 3) return null;
      return jwt;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await instance?.signOut();
    } catch (_) {}
  }
}

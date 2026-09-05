import "package:clerk_flutter/clerk_flutter.dart";
import "package:flutter/foundation.dart";

/// Global session for Dio + router.
/// Web: [setManualToken] after hosted Clerk + JWT paste.
class ClerkAuthHolder {
  static ClerkAuthState? instance;
  static String? _manualJwt;

  static bool get isSignedIn {
    if (_manualJwt != null && _manualJwt!.split(".").length == 3) {
      return true;
    }
    final s = instance;
    if (s == null) return false;
    try {
      return s.isSignedIn;
    } catch (_) {
      return false;
    }
  }

  static void setManualToken(String? jwt) {
    if (jwt == null || jwt.trim().isEmpty) {
      _manualJwt = null;
      return;
    }
    final t = jwt.trim();
    if (t.split(".").length != 3) {
      debugPrint("[ClerkAuthHolder] reject non-JWT");
      _manualJwt = null;
      return;
    }
    _manualJwt = t;
    debugPrint("[ClerkAuthHolder] manual JWT set len=${t.length}");
  }

  static void clearManualToken() {
    _manualJwt = null;
  }

  static Future<String?> getToken() async {
    if (_manualJwt != null && _manualJwt!.split(".").length == 3) {
      return _manualJwt;
    }
    final s = instance;
    if (s == null) return null;
    try {
      final token = await s.sessionToken();
      final jwt = token.jwt;
      if (jwt.isEmpty || jwt.split(".").length != 3) return null;
      return jwt;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() async {
    clearManualToken();
    try {
      await instance?.signOut();
    } catch (_) {}
    instance = null;
  }
}
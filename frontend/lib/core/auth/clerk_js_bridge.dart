import "dart:async";
import "dart:js_util" as js_util;
import "package:flutter/foundation.dart";
import "../../config/env.dart";

class ClerkJsBridge {
  static dynamic _clerk;
  static dynamic _pendingSignIn;

  static const _scriptUrls = [
    "https://cute-lobster-2676.clerk.accounts.dev/npm/@clerk/clerk-js@5/dist/clerk.browser.js",
    "https://cdn.jsdelivr.net/npm/@clerk/clerk-js@5/dist/clerk.browser.js",
    "https://unpkg.com/@clerk/clerk-js@5/dist/clerk.browser.js",
  ];

  static Future<void> _injectScript(String pk) async {
    if (js_util.getProperty(js_util.globalThis, "Clerk") != null) return;
    final document = js_util.getProperty(js_util.globalThis, "document");
    Object? lastError;
    for (final url in _scriptUrls) {
      try {
        final c = Completer<void>();
        final script = js_util.callMethod(document, "createElement", ["script"]);
        js_util.setProperty(script, "src", url);
        js_util.setProperty(script, "async", true);
        js_util.setProperty(script, "crossOrigin", "anonymous");
        js_util.callMethod(
            script, "setAttribute", ["data-clerk-publishable-key", pk]);
        js_util.setProperty(
            script, "onload", js_util.allowInterop((_) {
          if (!c.isCompleted) c.complete();
        }));
        js_util.setProperty(
            script, "onerror", js_util.allowInterop((_) {
          if (!c.isCompleted) c.completeError(Exception(url));
        }));
        js_util.callMethod(
            js_util.getProperty(document, "head"), "appendChild", [script]);
        await c.future.timeout(const Duration(seconds: 15));
        return;
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception("CDN failed: $lastError");
  }

  static Future<void> ensureLoaded() async {
    if (_clerk != null) return;
    final pk = Env.clerkPublishableKey;
    if (pk.isEmpty || pk.contains("REPLACE")) {
      throw Exception("CLERK_PUBLISHABLE_KEY missing");
    }
    await _injectScript(pk);
    dynamic g;
    for (var i = 0; i < 50; i++) {
      g = js_util.getProperty(js_util.globalThis, "Clerk");
      if (g != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (g == null) throw Exception("window.Clerk null");
    final hasLoad = js_util.hasProperty(g, "load");
    final hasClient = js_util.hasProperty(g, "client");
    _clerk = (hasLoad || hasClient) ? g : js_util.callConstructor(g, [pk]);
    try {
      final p = js_util.callMethod(_clerk, "load", []);
      if (p != null) await js_util.promiseToFuture(p);
    } catch (_) {}
  }

  /// Returns jwt, or throws with message starting NEED_2FA:
  static Future<String> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await ensureLoaded();
    final client = js_util.getProperty(_clerk, "client");
    final signIn = js_util.getProperty(client, "signIn");

    await js_util.promiseToFuture(
      js_util.callMethod(signIn, "create", [
        js_util.jsify({"identifier": email, "password": password}),
      ]),
    );

    final status = js_util.getProperty(signIn, "status")?.toString() ?? "";
    if (status == "complete") {
      final sid = js_util.getProperty(signIn, "createdSessionId")?.toString();
      if (sid != null && sid.isNotEmpty && sid != "null") {
        await _activate(sid);
        return _token();
      }
    }

    if (status == "needs_second_factor") {
      _pendingSignIn = signIn;
      // Prepare email_code if available
      try {
        await js_util.promiseToFuture(
          js_util.callMethod(signIn, "prepareSecondFactor", [
            js_util.jsify({"strategy": "email_code"}),
          ]),
        );
      } catch (e) {
        debugPrint("prepareSecondFactor: $e");
      }
      throw Exception("NEED_2FA:Enter the verification code sent to your email");
    }

    if (status == "needs_first_factor") {
      throw Exception("Additional first factor required (status: $status)");
    }

    final sid = js_util.getProperty(signIn, "createdSessionId")?.toString();
    if (sid != null && sid.isNotEmpty && sid != "null") {
      await _activate(sid);
      return _token();
    }
    throw Exception("Sign-in status: $status");
  }

  static Future<String> completeSecondFactor(String code) async {
    await ensureLoaded();
    final signIn = _pendingSignIn;
    if (signIn == null) {
      throw Exception("No pending sign-in — enter password again");
    }

    // Try email_code then totp
    Object? last;
    for (final strategy in ["email_code", "totp", "phone_code"]) {
      try {
        await js_util.promiseToFuture(
          js_util.callMethod(signIn, "attemptSecondFactor", [
            js_util.jsify({"strategy": strategy, "code": code}),
          ]),
        );
        last = null;
        break;
      } catch (e) {
        last = e;
        debugPrint("attemptSecondFactor $strategy: $e");
      }
    }
    if (last != null) {
      throw Exception("Invalid code. Try again.");
    }

    final status = js_util.getProperty(signIn, "status")?.toString() ?? "";
    final sid = js_util.getProperty(signIn, "createdSessionId")?.toString();
    if (sid == null || sid.isEmpty || sid == "null") {
      throw Exception("2FA done but no session (status: $status)");
    }
    await _activate(sid);
    _pendingSignIn = null;
    return _token();
  }

  static Future<String> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    await ensureLoaded();
    final client = js_util.getProperty(_clerk, "client");
    final signUp = js_util.getProperty(client, "signUp");
    await js_util.promiseToFuture(
      js_util.callMethod(signUp, "create", [
        js_util.jsify({"emailAddress": email, "password": password}),
      ]),
    );
    final status = js_util.getProperty(signUp, "status")?.toString() ?? "";
    final sid = js_util.getProperty(signUp, "createdSessionId")?.toString();
    if (sid != null && sid.isNotEmpty && sid != "null") {
      await _activate(sid);
      return _token();
    }
    throw Exception("Sign-up status: $status");
  }

  static Future<void> _activate(String sessionId) async {
    await js_util.promiseToFuture(
      js_util.callMethod(_clerk, "setActive", [
        js_util.jsify({"session": sessionId}),
      ]),
    );
  }

  static Future<String> _token() async {
    final session = js_util.getProperty(_clerk, "session");
    if (session == null) throw Exception("No session");
    final token = await js_util.promiseToFuture(
      js_util.callMethod(session, "getToken", []),
    );
    final jwt = token?.toString() ?? "";
    if (jwt.split(".").length != 3) throw Exception("Bad token");
    return jwt;
  }
}
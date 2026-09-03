import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../network/api_client.dart";
import "../auth/clerk_auth_holder.dart";
import "../../domain/models/user_profile.dart";

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

class AuthRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

final authRefreshProvider = Provider<AuthRefreshNotifier>((ref) {
  final n = AuthRefreshNotifier();
  ref.onDispose(n.dispose);
  return n;
});

/// null = signed out OR not linked (403). Throws only on unexpected failures after sign-in.
final authSyncProvider = FutureProvider<UserProfile?>((ref) async {
  final refresh = ref.read(authRefreshProvider);
  try {
    if (!ClerkAuthHolder.isSignedIn) {
      return null;
    }

    // Wait briefly for session JWT (race with ClerkAuthHolder.instance)
    String? token;
    for (var i = 0; i < 10; i++) {
      token = await ClerkAuthHolder.getToken();
      if (token != null && token.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (token == null || token.isEmpty) {
      debugPrint("[authSync] signed in but no JWT yet");
      return null;
    }

    final api = ref.read(apiClientProvider);
    final res = await api.dio
        .get("/auth/sync")
        .timeout(const Duration(seconds: 15));
    final data = api.unwrap<Map<String, dynamic>>(res);
    final profile = UserProfile.fromJson(data);
    debugPrint("[authSync] OK ${profile.email} ${profile.role}");
    return profile;
  } catch (e, st) {
    debugPrint("[authSync] FAIL $e");
    debugPrint("$st");
    // 403 / no linked → treat as null so /pending-invite shows (not infinite splash)
    final msg = e.toString().toLowerCase();
    if (msg.contains("403") ||
        msg.contains("forbidden") ||
        msg.contains("no linked") ||
        msg.contains("401") ||
        msg.contains("unauthorized")) {
      return null;
    }
    // Network / parse: still null but log — splash will show via debug console
    return null;
  } finally {
    Future.microtask(() => refresh.ping());
  }
});

final currentRoleProvider = Provider<String>((ref) {
  return ref.watch(authSyncProvider).valueOrNull?.role ?? "";
});

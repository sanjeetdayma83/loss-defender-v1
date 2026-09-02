import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../network/api_client.dart";
import "../auth/clerk_auth_holder.dart";
import "../../domain/models/user_profile.dart";

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

/// GoRouter must re-redirect when /auth/sync settles — Clerk alone does not notify.
class AuthRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

final authRefreshProvider = Provider<AuthRefreshNotifier>((ref) {
  final n = AuthRefreshNotifier();
  ref.onDispose(n.dispose);
  return n;
});

final authSyncProvider = FutureProvider<UserProfile?>((ref) async {
  final refresh = ref.read(authRefreshProvider);
  try {
    if (!ClerkAuthHolder.isSignedIn) {
      return null;
    }
    final api = ref.read(apiClientProvider);
    final res = await api.dio
        .get("/auth/sync")
        .timeout(const Duration(seconds: 12));
    final data = api.unwrap<Map<String, dynamic>>(res);
    return UserProfile.fromJson(data);
  } catch (_) {
    return null;
  } finally {
    Future.microtask(() => refresh.ping());
  }
});

final currentRoleProvider = Provider<String>((ref) {
  return ref.watch(authSyncProvider).valueOrNull?.role ?? "";
});
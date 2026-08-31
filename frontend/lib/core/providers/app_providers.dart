import "package:flutter_riverpod/flutter_riverpod.dart";
import "../network/api_client.dart";
import "../auth/clerk_auth_holder.dart";
import "../../domain/models/user_profile.dart";

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

/// Calls GET /auth/sync. Returns null if not signed in OR if the Clerk
/// identity has no linked User row yet (invite not accepted -> 403).
final authSyncProvider = FutureProvider<UserProfile?>((ref) async {
  if (!ClerkAuthHolder.isSignedIn) return null;
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.dio.get("/auth/sync");
    final data = api.unwrap<Map<String, dynamic>>(res);
    return UserProfile.fromJson(data);
  } catch (_) {
    return null;
  }
});

final currentRoleProvider = Provider<String>((ref) {
  return ref.watch(authSyncProvider).valueOrNull?.role ?? "";
});
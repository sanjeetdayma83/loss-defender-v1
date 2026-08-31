import "package:flutter_riverpod/flutter_riverpod.dart";
import "../network/api_client.dart";

class AppSession {
  const AppSession({
    this.token,
    this.userId,
    this.companyId,
    this.role,
    this.email,
    this.warehouseId,
    this.clerkUserId,
  });

  final String? token;
  final String? userId;
  final String? companyId;
  final String? role;
  final String? email;
  final String? warehouseId;
  final String? clerkUserId;

  bool get isSignedIn =>
      token != null && token!.isNotEmpty && userId != null;
}

class SessionNotifier extends StateNotifier<AppSession> {
  SessionNotifier() : super(const AppSession());

  final _api = ApiClient.instance;

  Future<void> bootstrap() async {
    final token = await _api.getToken();
    if (token == null || token.isEmpty) {
      state = const AppSession();
      return;
    }
    await applyToken(token);
  }

  /// Clerk session JWT → backend /auth/sync → AppSession
  Future<String?> applyToken(String token, {String? clerkUserId}) async {
    final t = token.trim();
    if (t.isEmpty) return "Empty token";
    await _api.setToken(t);
    try {
      final res = await _api.dio.get("/auth/sync");
      final d = res.data["data"] as Map<String, dynamic>;
      state = AppSession(
        token: t,
        userId: d["id"]?.toString(),
        companyId: d["companyId"]?.toString(),
        role: d["role"]?.toString(),
        email: d["email"]?.toString(),
        warehouseId: d["warehouseId"]?.toString(),
        clerkUserId: clerkUserId ?? d["clerkId"]?.toString(),
      );
      return null;
    } catch (e) {
      await _api.setToken(null);
      state = const AppSession();
      return e.toString();
    }
  }

  Future<String?> signInWithToken(String token) => applyToken(token);

  Future<void> signOut() async {
    try {
      await _api.dio.post("/auth/logout");
    } catch (_) {}
    await _api.setToken(null);
    state = const AppSession();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, AppSession>((ref) => SessionNotifier());
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
  });

  final String? token;
  final String? userId;
  final String? companyId;
  final String? role;
  final String? email;
  final String? warehouseId;

  bool get isSignedIn => token != null && token!.isNotEmpty && userId != null;

  AppSession copyWith({
    String? token,
    String? userId,
    String? companyId,
    String? role,
    String? email,
    String? warehouseId,
  }) =>
      AppSession(
        token: token ?? this.token,
        userId: userId ?? this.userId,
        companyId: companyId ?? this.companyId,
        role: role ?? this.role,
        email: email ?? this.email,
        warehouseId: warehouseId ?? this.warehouseId,
      );
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
    await _api.setToken(token);
    try {
      final res = await _api.dio.get("/auth/sync");
      final d = res.data["data"] as Map<String, dynamic>;
      state = AppSession(
        token: token,
        userId: d["id"]?.toString(),
        companyId: d["companyId"]?.toString(),
        role: d["role"]?.toString(),
        email: d["email"]?.toString(),
        warehouseId: d["warehouseId"]?.toString(),
      );
    } catch (_) {
      await _api.setToken(null);
      state = const AppSession();
    }
  }

  /// Dev / until Clerk UI is wired: paste session JWT
  Future<String?> signInWithToken(String token) async {
    await _api.setToken(token.trim());
    try {
      final res = await _api.dio.get("/auth/sync");
      final d = res.data["data"] as Map<String, dynamic>;
      state = AppSession(
        token: token.trim(),
        userId: d["id"]?.toString(),
        companyId: d["companyId"]?.toString(),
        role: d["role"]?.toString(),
        email: d["email"]?.toString(),
        warehouseId: d["warehouseId"]?.toString(),
      );
      return null;
    } catch (e) {
      await _api.setToken(null);
      state = const AppSession();
      return e.toString();
    }
  }

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
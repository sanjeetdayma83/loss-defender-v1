import "package:dio/dio.dart";
import "../../config/env.dart";
import "../auth/clerk_auth_holder.dart";

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => "ApiException($statusCode): $message";
}

class ApiClient {
  static final ApiClient instance = ApiClient._internal();

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {"Content-Type": "application/json"},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ClerkAuthHolder.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
        }
        handler.next(options);
      },
      onError: (e, handler) => handler.next(e),
    ));
  }

  /// Unwraps the backend's {success, data, error, meta} envelope.
  T unwrap<T>(Response res) {
    final body = res.data;
    if (body is Map && body["success"] == true) {
      return body["data"] as T;
    }
    final msg = body is Map
        ? (body["error"]?.toString() ?? body["message"]?.toString())
        : null;
    throw ApiException(res.statusCode, msg ?? "Unexpected response");
  }

  Map<String, dynamic>? meta(Response res) {
    final body = res.data;
    if (body is Map && body["meta"] is Map) {
      return Map<String, dynamic>.from(body["meta"] as Map);
    }
    return null;
  }

  String friendlyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data["message"] != null) return data["message"].toString();
      if (data is Map && data["error"] != null) return data["error"].toString();
      return e.message ?? "Network error";
    }
    if (e is ApiException) return e.message;
    return e.toString();
  }

  // --- Backward-compat shim for old session_provider.dart ---
  // Token handling is now fully owned by Clerk (see ClerkAuthHolder).
  // Clerk's SDK persists and refreshes its own session internally, so
  // there is nothing for setToken() to actually store anymore — it's a
  // deliberate no-op kept only so older callers still compile.
  Future<String?> getToken() => ClerkAuthHolder.getToken();
  Future<void> setToken(String? token) async {
    // Intentional no-op — see comment above.
  }
}
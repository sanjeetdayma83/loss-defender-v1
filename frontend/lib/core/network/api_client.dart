import "package:dio/dio.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "../../config/env.dart";

class ApiClient {
  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
        }
        handler.next(options);
      },
    ));
  }

  static final ApiClient instance = ApiClient._();
  late final Dio dio;
  static const _tokenKey = "clerk_session_token";
  final _storage = const FlutterSecureStorage();

  Future<void> setToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);
}
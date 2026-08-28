import "package:dio/dio.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "../../config/env.dart";

class ApiClient {
  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {"Content-Type": "application/json"},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: "clerk_session_token");
        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
        }
        handler.next(options);
      },
      onError: (e, handler) {
        handler.next(e);
      },
    ));
  }

  Future<void> setToken(String? token) async {
    if (token == null) {
      await _storage.delete(key: "clerk_session_token");
    } else {
      await _storage.write(key: "clerk_session_token", value: token);
    }
  }
}
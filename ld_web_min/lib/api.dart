import "package:dio/dio.dart";
import "config/env.dart";

class Api {
  static final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    headers: {"Content-Type": "application/json"},
  ));

  static void setToken(String? token) {
    if (token == null || token.isEmpty) {
      dio.options.headers.remove("Authorization");
    } else {
      dio.options.headers["Authorization"] = "Bearer $token";
    }
  }

  static Future<Map<String, dynamic>> health() async {
    final r = await dio.get("/health");
    return Map<String, dynamic>.from(r.data as Map);
  }

  static Future<Map<String, dynamic>> sync() async {
    final r = await dio.get("/auth/sync");
    return Map<String, dynamic>.from(r.data as Map);
  }

  static Future<Map<String, dynamic>> companyMe() async {
    final r = await dio.get("/companies/me");
    return Map<String, dynamic>.from(r.data as Map);
  }

  static Future<Map<String, dynamic>> orders() async {
    final r = await dio.get("/orders");
    return Map<String, dynamic>.from(r.data as Map);
  }
}
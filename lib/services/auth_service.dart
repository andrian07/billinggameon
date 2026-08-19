import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {"username": username, "password": password},
      );

      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          throw const AuthException("Format respons login tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const AuthException("Format respons login tidak valid.");
      }

      if (data["code"].toString() != "200") {
        final result = data["result"];
        final message = result is String
            ? result
            : data["message"]?.toString();
        throw AuthException(message ?? "Login gagal.");
      }

      final result = data["result"];
      if (result is! Map<String, dynamic>) {
        throw const AuthException("Format respons login tidak valid.");
      }

      return result;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData["message"] != null) {
        throw AuthException(responseData["message"].toString());
      }

      if (e.response != null) {
        throw AuthException(
          "Login gagal (${e.response?.statusCode}). Periksa username/password Anda.",
        );
      }

      throw const AuthException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

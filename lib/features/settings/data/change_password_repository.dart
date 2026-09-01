import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';

class ChangePasswordRepositoryException implements Exception {
  final String message;

  const ChangePasswordRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Self-service "change my own password" via Auth/change_password — distinct
/// from Master/reset_pass_user (admin-only, resets another user to a fixed
/// default without verifying anything).
class ChangePasswordRepository {
  final Dio _dio = Dio();

  Future<void> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.changePassword,
        data: {
          "user_id": userId,
          "old_password": oldPassword,
          "new_password": newPassword,
        },
      );

      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          throw const ChangePasswordRepositoryException(
            "Format respons tidak valid.",
          );
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const ChangePasswordRepositoryException(
          "Format respons tidak valid.",
        );
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw ChangePasswordRepositoryException(
          data['result']?.toString() ?? "Gagal mengubah password.",
        );
      }
    } on ChangePasswordRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['result'] != null) {
        throw ChangePasswordRepositoryException(
          responseData['result'].toString(),
        );
      }
      throw const ChangePasswordRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

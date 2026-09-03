import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';

class BroadcastRepositoryException implements Exception {
  final String message;

  const BroadcastRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Kirim pesan free-text ke SEMUA member. billing_api mem-proxy ke gameon
/// (Api/broadcast_notification) yang membuat 1 notifikasi in-app per member +
/// push FCM ke topic.
class BroadcastRepository {
  final Dio _dio = Dio();

  /// Returns the server's result message (e.g. "Broadcast terkirim ke 12 member").
  /// [userId] dipakai backend untuk memastikan pemanggil adalah akun owner
  /// (ms_user.userrole == 1) — broadcast bukan menu role-gated biasa.
  Future<String> sendBroadcast({
    required String message,
    required int userId,
    String title = "",
  }) async {
    final data = await _post(ApiEndpoints.broadcastMember, {
      "title": title.trim(),
      "message": message.trim(),
      "user_id": userId,
    });
    return data['result']?.toString() ?? "Broadcast terkirim";
  }

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(url, data: payload);

      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          throw const BroadcastRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const BroadcastRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw BroadcastRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on BroadcastRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw BroadcastRepositoryException(responseData['message'].toString());
      }
      throw const BroadcastRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

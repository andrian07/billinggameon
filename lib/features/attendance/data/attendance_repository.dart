import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';

class AttendanceRepositoryException implements Exception {
  final String message;

  const AttendanceRepositoryException(this.message);

  @override
  String toString() => message;
}

enum AttendanceAction {
  checkIn,
  checkOut;

  static AttendanceAction fromApiValue(String value) {
    return value.trim().toLowerCase() == "check_out"
        ? AttendanceAction.checkOut
        : AttendanceAction.checkIn;
  }
}

class AttendanceResult {
  final String message;
  final AttendanceAction action;
  final int absensiId;

  const AttendanceResult({
    required this.message,
    required this.action,
    required this.absensiId,
  });
}

/// Records an employee attendance scan via Auth/add_absensi/{user_id} — a
/// plain GET, no body. The QR printed on a user's card/badge (see
/// Master/user_qrcode) encodes just that user's id; a hardware scanner
/// types the decoded value followed by Enter wherever the field has focus,
/// so the caller just needs the parsed user id to hit this endpoint. The
/// backend toggles check-in/check-out itself based on today's existing
/// record for that user.
class AttendanceRepository {
  final Dio _dio = Dio();

  Future<AttendanceResult> scanAttendance(int userId) async {
    try {
      final response = await _dio.get("${ApiEndpoints.addAbsensi}/$userId");

      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          throw const AttendanceRepositoryException(
            "Format respons tidak valid.",
          );
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const AttendanceRepositoryException(
          "Format respons tidak valid.",
        );
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw AttendanceRepositoryException(
          data['result']?.toString() ??
              data['message']?.toString() ??
              "Absensi gagal.",
        );
      }

      final rawId = data['absensi_id'];
      return AttendanceResult(
        message: data['result']?.toString() ?? "Absensi berhasil.",
        action: AttendanceAction.fromApiValue(
          data['action']?.toString() ?? "",
        ),
        absensiId: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "") ?? 0,
      );
    } on AttendanceRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['result'] != null) {
        throw AttendanceRepositoryException(responseData['result'].toString());
      }
      throw const AttendanceRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';

class PinRepositoryException implements Exception {
  final String message;

  const PinRepositoryException(this.message);

  @override
  String toString() => message;
}

class PinStatus {
  final bool active;
  final bool isSet;

  const PinStatus({required this.active, required this.isSet});

  factory PinStatus.fromJson(Map<String, dynamic> json) {
    return PinStatus(
      active: json['active'] == true,
      isSet: json['is_set'] == true,
    );
  }

  static const empty = PinStatus(active: false, isSet: false);
}

/// PIN keamanan global (satu PIN untuk seluruh aplikasi) yang wajib
/// dimasukkan sebelum tindakan destruktif (batal meja, cancel transaksi
/// cafe, hapus keep transaction) apabila diaktifkan oleh owner - lihat
/// Pin.php di backend. Mengatur PIN (set/aktifkan) hanya bisa oleh owner,
/// tapi status() dan verify() bisa dipanggil siapa saja yang sedang login.
class PinRepository {
  final Dio _dio = Dio();

  Future<PinStatus> getStatus() async {
    final data = await _post(ApiEndpoints.pinStatus, {});
    final result = data['result'];
    if (result is! Map<String, dynamic>) {
      throw const PinRepositoryException("Format respons status PIN tidak valid.");
    }
    return PinStatus.fromJson(result);
  }

  Future<void> setPin({required int userId, required String pinCode}) async {
    await _post(ApiEndpoints.pinSet, {
      "user_id": userId,
      "pin_code": pinCode,
    });
  }

  Future<void> setActive({required int userId, required bool active}) async {
    await _post(ApiEndpoints.pinSetActive, {
      "user_id": userId,
      "active": active,
    });
  }

  Future<bool> verify(String pinCode) async {
    try {
      await _post(ApiEndpoints.pinVerify, {"pin_code": pinCode});
      return true;
    } on PinRepositoryException {
      return false;
    }
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
          throw const PinRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const PinRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw PinRepositoryException(
          data['result']?.toString() ?? "Permintaan gagal.",
        );
      }

      return data;
    } on PinRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['result'] != null) {
        throw PinRepositoryException(responseData['result'].toString());
      }
      throw const PinRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

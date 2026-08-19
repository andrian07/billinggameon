import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/cashier_summary.dart';

class CashierRepositoryException implements Exception {
  final String message;

  const CashierRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Reads a cashier's today-so-far transaction summary via
/// Report/get_transaction_today_by_cashier, used by the "Tutup Kas" flow.
class CashierRepository {
  final Dio _dio = Dio();

  Future<CashierClosingSummary> getTodaySummary({required int userId}) async {
    final data = await _post(ApiEndpoints.transactionTodayByCashier, {
      "user_id": userId,
    });

    final result = data['result'];
    if (result is! Map<String, dynamic>) {
      throw const CashierRepositoryException(
        "Format respons ringkasan kasir tidak valid.",
      );
    }

    return CashierClosingSummary.fromJson(result);
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
          throw const CashierRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const CashierRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw CashierRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on CashierRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw CashierRepositoryException(responseData['message'].toString());
      }
      throw const CashierRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

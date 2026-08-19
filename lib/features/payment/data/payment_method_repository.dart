import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/payment_method.dart';

class PaymentMethodRepositoryException implements Exception {
  final String message;

  const PaymentMethodRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Reads active payment methods via Master/get_payment_list — used by the
/// billing and cafe payment dialogs, and joined against transaction history
/// to resolve a stored payment_id back into a display name.
class PaymentMethodRepository {
  final Dio _dio = Dio();

  Future<List<PaymentMethod>> getPaymentMethods() async {
    final data = await _post(ApiEndpoints.paymentList, {});

    final result = data['result'];
    if (result is! List) {
      throw const PaymentMethodRepositoryException(
        "Format respons daftar metode pembayaran tidak valid.",
      );
    }

    return result
        .whereType<Map<String, dynamic>>()
        .map(PaymentMethod.fromJson)
        .toList();
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
          throw const PaymentMethodRepositoryException(
            "Format respons tidak valid.",
          );
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const PaymentMethodRepositoryException(
          "Format respons tidak valid.",
        );
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw PaymentMethodRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on PaymentMethodRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw PaymentMethodRepositoryException(
          responseData['message'].toString(),
        );
      }
      throw const PaymentMethodRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

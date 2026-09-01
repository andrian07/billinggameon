import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/price_setting.dart';

class PriceRepositoryException implements Exception {
  final String message;

  const PriceRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Reads and updates hourly price settings via the Master/*_price endpoints.
class PriceRepository {
  final Dio _dio = Dio();

  Future<List<PriceSetting>> getPrices() async {
    final data = await _post(ApiEndpoints.priceList, const {});

    final list = data['data'];
    if (list is! List) {
      throw const PriceRepositoryException(
        "Format respons daftar harga tidak valid.",
      );
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(PriceSetting.fromJson)
        .toList();
  }

  Future<void> editPrice({
    required int id,
    required int price,
    required int price2,
    required int price3,
  }) {
    return _post(ApiEndpoints.editPrice, {
      "master_price_id": "$id",
      "price": "$price",
      "price_2": "$price2",
      "price_3": "$price3",
    });
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
          throw const PriceRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const PriceRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw PriceRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on PriceRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw PriceRepositoryException(responseData['message'].toString());
      }
      throw const PriceRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

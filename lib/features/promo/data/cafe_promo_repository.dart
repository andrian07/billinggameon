import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/cafe_promo.dart';
import '../../../models/pagination_info.dart';

class CafePromoRepositoryException implements Exception {
  final String message;

  const CafePromoRepositoryException(this.message);

  @override
  String toString() => message;
}

class CafePromoListResult {
  final List<CafePromo> promos;
  final PaginationInfo pagination;

  const CafePromoListResult({required this.promos, required this.pagination});
}

/// CRUD promo cafe via Master/*_cafe_promo. Katalog ini lokal di billing_api
/// (bukan gameon) - harga menu memang per-cabang.
class CafePromoRepository {
  final Dio _dio = Dio();

  Future<CafePromoListResult> getPromos({
    required int page,
    required int perPage,
  }) async {
    final data = await _post(ApiEndpoints.cafePromoList, {
      "page": page,
      "per_page": perPage,
    });

    final list = data['data'];
    if (list is! List) {
      throw const CafePromoRepositoryException(
        "Format respons daftar promo cafe tidak valid.",
      );
    }

    final promos = list
        .whereType<Map<String, dynamic>>()
        .map(CafePromo.fromJson)
        .toList();

    final paginationJson = data['pagination'];
    final pagination = paginationJson is Map<String, dynamic>
        ? PaginationInfo.fromJson(paginationJson)
        : PaginationInfo.empty;

    return CafePromoListResult(promos: promos, pagination: pagination);
  }

  /// Semua promo cafe aktif tanpa paginasi - dipakai dropdown promo di POS.
  Future<List<CafePromo>> getAllPromos() async {
    final data = await _post(ApiEndpoints.cafePromoListNoPaging, const {});
    final list = data['result'] ?? data['data'];
    if (list is! List) {
      throw const CafePromoRepositoryException(
        "Format respons daftar promo cafe tidak valid.",
      );
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(CafePromo.fromJson)
        .toList();
  }

  Future<void> addPromo({
    required String name,
    required int price,
    required List<int> productIds,
  }) {
    return _post(ApiEndpoints.addCafePromo, {
      "name": name.trim(),
      "price": price,
      "product_ids": productIds,
    });
  }

  Future<void> editPromo({
    required int id,
    String? name,
    int? price,
    List<int>? productIds,
    bool? active,
  }) {
    return _post(ApiEndpoints.editCafePromo, {
      "ms_cafe_promo_id": id,
      if (name != null) "name": name.trim(),
      if (price != null) "price": price,
      if (productIds != null) "product_ids": productIds,
      if (active != null) "active": active ? "Y" : "N",
    });
  }

  Future<void> deletePromo(int id) {
    return _post(ApiEndpoints.deleteCafePromo, {"ms_cafe_promo_id": id});
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
          throw const CafePromoRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const CafePromoRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw CafePromoRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on CafePromoRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw CafePromoRepositoryException(responseData['message'].toString());
      }
      throw const CafePromoRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

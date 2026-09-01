import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/pagination_info.dart';
import '../../../models/stock_opname.dart';

class OpnameRepositoryException implements Exception {
  final String message;

  const OpnameRepositoryException(this.message);

  @override
  String toString() => message;
}

class OpnameItemInput {
  final int productId;
  final int physicalStock;

  const OpnameItemInput({
    required this.productId,
    required this.physicalStock,
  });
}

class OpnameListResult {
  final List<StockOpname> opnames;
  final PaginationInfo pagination;

  const OpnameListResult({required this.opnames, required this.pagination});
}

/// Stock opname (physical count reconciliation) via the Opname/* endpoints.
/// Owner-only: opname_add is rejected server-side for any account whose
/// ms_user.userrole isn't 1, regardless of what the client sends.
class OpnameRepository {
  final Dio _dio = Dio();

  Future<List<OpnameProduct>> getProducts() async {
    final data = await _post(ApiEndpoints.opnameProductList, {});

    final result = data['result'];
    if (result is! List) {
      throw const OpnameRepositoryException(
        "Format respons daftar produk tidak valid.",
      );
    }

    return result
        .whereType<Map<String, dynamic>>()
        .map(OpnameProduct.fromJson)
        .toList();
  }

  Future<OpnameListResult> getOpnames({
    required int page,
    required int perPage,
  }) async {
    final data = await _post(ApiEndpoints.opnameList, {
      "page": page,
      "per_page": perPage,
    });

    final result = data['result'];
    final rows = result is Map<String, dynamic> ? result['data'] : null;
    if (rows is! List) {
      throw const OpnameRepositoryException(
        "Format respons daftar opname tidak valid.",
      );
    }

    final opnames = rows
        .whereType<Map<String, dynamic>>()
        .map(StockOpname.fromJson)
        .toList();

    final paginationJson = result is Map<String, dynamic>
        ? result['pagination']
        : null;
    final pagination = paginationJson is Map<String, dynamic>
        ? PaginationInfo.fromJson(paginationJson)
        : PaginationInfo.empty;

    return OpnameListResult(opnames: opnames, pagination: pagination);
  }

  Future<StockOpnameDetail> getOpnameDetail(int opnameId) async {
    final data = await _post(ApiEndpoints.opnameList, {"opname_id": opnameId});

    final result = data['result'];
    if (result is! Map<String, dynamic>) {
      throw const OpnameRepositoryException(
        "Format detail opname tidak valid.",
      );
    }

    return StockOpnameDetail.fromJson(result);
  }

  Future<int> addOpname({
    required int userId,
    String? note,
    required String createdBy,
    required List<OpnameItemInput> items,
  }) async {
    final data = await _post(ApiEndpoints.opnameAdd, {
      "user_id": userId,
      if (note != null && note.trim().isNotEmpty) "note": note.trim(),
      "created_by": createdBy,
      "items": [
        for (final item in items)
          {"product_id": item.productId, "physical_stock": item.physicalStock},
      ],
    });

    final rawId = data['opname_id'];
    return rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "") ?? 0;
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
          throw const OpnameRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const OpnameRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw OpnameRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on OpnameRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw OpnameRepositoryException(responseData['message'].toString());
      }
      throw const OpnameRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

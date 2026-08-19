import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/pagination_info.dart';
import '../../../models/purchase.dart';

class PurchaseRepositoryException implements Exception {
  final String message;

  const PurchaseRepositoryException(this.message);

  @override
  String toString() => message;
}

/// An item picked in the purchase form — [price] is left null to let the
/// server fall back to the product's `product_cogs`.
class PurchaseItemInput {
  final int productId;
  final int qty;
  final int? price;

  const PurchaseItemInput({
    required this.productId,
    required this.qty,
    this.price,
  });
}

class PurchaseListResult {
  final List<Purchase> purchases;
  final PaginationInfo pagination;

  const PurchaseListResult({
    required this.purchases,
    required this.pagination,
  });
}

/// Reads and manages stock purchases via the Purchase/* endpoints.
///
/// purchase_add automatically increases product stock and logs a stock
/// movement; purchase_cancel reverses both.
class PurchaseRepository {
  final Dio _dio = Dio();

  Future<PurchaseListResult> getPurchases({
    required int page,
    required int perPage,
  }) async {
    final data = await _post(ApiEndpoints.purchaseList, {
      "page": page,
      "per_page": perPage,
    });

    final result = data['result'];
    final rows = result is Map<String, dynamic> ? result['data'] : null;
    if (rows is! List) {
      throw const PurchaseRepositoryException(
        "Format respons daftar pembelian tidak valid.",
      );
    }

    final purchases = rows
        .whereType<Map<String, dynamic>>()
        .map(Purchase.fromJson)
        .toList();

    final paginationJson = result is Map<String, dynamic>
        ? result['pagination']
        : null;
    final pagination = paginationJson is Map<String, dynamic>
        ? PaginationInfo.fromJson(paginationJson)
        : PaginationInfo.empty;

    return PurchaseListResult(purchases: purchases, pagination: pagination);
  }

  Future<List<PurchaseProduct>> getPurchaseProducts() async {
    final data = await _post(ApiEndpoints.purchaseListProduct, {});

    final result = data['result'];
    if (result is! List) {
      throw const PurchaseRepositoryException(
        "Format respons daftar produk tidak valid.",
      );
    }

    return result
        .whereType<Map<String, dynamic>>()
        .map(PurchaseProduct.fromJson)
        .toList();
  }

  Future<PurchaseDetail> getPurchaseDetail(int purchaseId) async {
    final data = await _post(ApiEndpoints.purchaseList, {
      "purchase_id": purchaseId,
    });

    final result = data['result'];
    if (result is! Map<String, dynamic>) {
      throw const PurchaseRepositoryException(
        "Format detail pembelian tidak valid.",
      );
    }

    return PurchaseDetail.fromJson(result);
  }

  Future<int> addPurchase({
    String? supplier,
    required String createdBy,
    required List<PurchaseItemInput> items,
  }) async {
    final data = await _post(ApiEndpoints.purchaseAdd, {
      if (supplier != null && supplier.trim().isNotEmpty)
        "supplier": supplier.trim(),
      "created_by": createdBy,
      "items": [
        for (final item in items)
          {
            "product_id": item.productId,
            "qty": item.qty,
            if (item.price != null) "price": item.price,
          },
      ],
    });

    final rawId = data['purchase_id'];
    return rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "") ?? 0;
  }

  Future<void> cancelPurchase({
    required int purchaseId,
    required String cancelledBy,
  }) {
    return _post(ApiEndpoints.purchaseCancel, {
      "purchase_id": purchaseId,
      "cancelled_by": cancelledBy,
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
          throw const PurchaseRepositoryException(
            "Format respons tidak valid.",
          );
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const PurchaseRepositoryException(
          "Format respons tidak valid.",
        );
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw PurchaseRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on PurchaseRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw PurchaseRepositoryException(responseData['message'].toString());
      }
      throw const PurchaseRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

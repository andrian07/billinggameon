import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/cart_item.dart';
import '../../../models/keep_transaction.dart';
import '../../billing/data/member_approval_repository.dart';

class CafeRepositoryException implements Exception {
  final String message;

  const CafeRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Header info handed back by [CafeRepository.keepTransaction] — returned
/// on every call (new or adding onto an existing hold) since the backend
/// re-reads the header row regardless, so the kitchen ticket always has a
/// code/name to print even when items are just being added to a hold that
/// already existed.
class KeepTransactionSaveResult {
  final int id;
  final String invoiceNumber;
  final String? name;

  const KeepTransactionSaveResult({
    required this.id,
    required this.invoiceNumber,
    this.name,
  });
}

/// Submits POS/cafe orders via the Cafe/* endpoints.
class CafeRepository {
  final Dio _dio = Dio();

  Future<int> submitTransactionCafe({
    int? customerId,
    int? promoId,
    String? promoNote,
    required int paymentId,
    int? table,
    String? customerName,
    required int tax,
    double discountPercent = 0,
    required String createdBy,
    required int paidBy,
    required List<CartItem> items,
    String? memberApprovalRef,
  }) async {
    final data = await _post(ApiEndpoints.saveTransactionCafe, {
      "customer_id": customerId ?? 0,
      "promo_id": promoId ?? 0,
      if (promoNote != null) "promo_note": promoNote,
      "payment_id": paymentId,
      "table": table,
      "customer_name": customerName,
      "tax": tax,
      "discount_percent": discountPercent,
      "created_by": createdBy,
      "paid_by": paidBy,
      if (memberApprovalRef != null) "member_approval_ref": memberApprovalRef,
      "items": [
        for (final item in items)
          {
            "product_id": item.product.id,
            "qty": item.quantity,
            if (item.note != null) "note": item.note,
            if (item.addons.isNotEmpty)
              "addons": [
                for (final addon in item.addons)
                  {"product_id": addon.product.id, "qty": addon.quantity},
              ],
          },
      ],
    });

    // Potong Saldo + member: backend menahan transaksi sampai member konfirmasi PIN
    if (data['result'] == 'NEED_MEMBER_APPROVAL') {
      final approval = data['approval'];
      throw MemberApprovalRequiredException.fromApproval(
        memberApprovalRef ?? "",
        approval is Map<String, dynamic> ? approval : null,
      );
    }

    final rawId = data['transaction_cafe_id'];
    return rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "") ?? 0;
  }

  /// Parks an order that hasn't been paid yet so it can be recalled later
  /// via [getKeepTransactions]/[getKeepTransactionDetail].
  ///
  /// Passing [keepTransactionId] targets an existing held transaction — the
  /// server adds [items] onto whatever it already has stored rather than
  /// creating a new record, so header fields (table/customer/promo/payment/
  /// tax/name) are only sent when creating a brand new one — [name] is
  /// ignored by the server once a keep transaction already exists.
  Future<KeepTransactionSaveResult> keepTransaction({
    int? keepTransactionId,
    String? name,
    int? table,
    int? customerId,
    int? promoId,
    int? paymentId,
    int tax = 0,
    required String createdBy,
    required List<CartItem> items,
  }) async {
    final payload = <String, dynamic>{
      "created_by": createdBy,
      "items": [
        for (final item in items)
          {
            "product_id": item.product.id,
            "qty": item.quantity,
            if (item.note != null) "note": item.note,
            if (item.addons.isNotEmpty)
              "addons": [
                for (final addon in item.addons)
                  {"product_id": addon.product.id, "qty": addon.quantity},
              ],
          },
      ],
    };

    if (keepTransactionId != null) {
      payload["keep_transaction_id"] = keepTransactionId;
    } else {
      if (name != null && name.trim().isNotEmpty) {
        payload["name"] = name.trim();
      }
      payload["table"] = table;
      payload["customer_id"] = customerId ?? 0;
      payload["promo_id"] = promoId ?? 0;
      payload["payment_id"] = paymentId ?? 0;
      payload["tax"] = tax;
    }

    final data = await _post(ApiEndpoints.keepTransactionCafe, payload);

    final rawId = data['keep_transaction_id'];
    final id = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? "") ?? keepTransactionId ?? 0;
    final rawName = data['keep_transaction_name']?.toString();

    return KeepTransactionSaveResult(
      id: id,
      invoiceNumber: data['keep_transaction_inv']?.toString() ?? "",
      name: (rawName == null || rawName.isEmpty) ? null : rawName,
    );
  }

  /// Lists every transaction currently on hold.
  Future<List<KeepTransaction>> getKeepTransactions() async {
    final data = await _post(ApiEndpoints.selectKeepTransactionCafe, {});
    final result = data['result'];
    if (result is! List) return const [];

    return [
      for (final item in result)
        if (item is Map<String, dynamic>) KeepTransaction.fromJson(item),
    ];
  }

  /// Fetches one held transaction with its line items, ready to resubmit to
  /// [submitTransactionCafe] once the cashier collects payment.
  Future<KeepTransactionDetail> getKeepTransactionDetail(
    int keepTransactionId,
  ) async {
    final data = await _post(ApiEndpoints.selectKeepTransactionCafe, {
      "keep_transaction_id": keepTransactionId,
    });
    final result = data['result'];
    if (result is! Map<String, dynamic>) {
      throw const CafeRepositoryException("Transaksi tidak ditemukan.");
    }

    return KeepTransactionDetail.fromJson(result);
  }

  /// Renames a held transaction (e.g. "Takeaway" -> the customer's actual
  /// name) — only takes effect while it's still status Keep. Passing an
  /// empty [name] clears it back to unnamed.
  Future<void> renameKeepTransaction(
    int keepTransactionId,
    String name,
  ) async {
    await _post(ApiEndpoints.renameKeepTransactionCafe, {
      "keep_transaction_id": keepTransactionId,
      "name": name,
    });
  }

  /// Deletes a held transaction outright — used when the cashier decides a
  /// parked order is no longer needed.
  Future<void> deleteKeepTransaction(int keepTransactionId) async {
    await _post(ApiEndpoints.deleteKeepTransactionCafe, {
      "keep_transaction_id": keepTransactionId,
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
          throw const CafeRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const CafeRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw CafeRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on CafeRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw CafeRepositoryException(responseData['message'].toString());
      }
      throw const CafeRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/topup_request.dart';

class TopupRepositoryException implements Exception {
  final String message;

  const TopupRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Reads and approves member self-service top up requests via the
/// Master/*_topup* endpoints, which proxy through to the gameon central
/// server (see GAMEON_PAYLOAD_SPEC.txt / application/libraries/Gameon.php).
class TopupRepository {
  final Dio _dio = Dio();

  /// Requests still waiting for a cashier to approve - pulled live from
  /// gameon on every call (not cached locally), also triggers billing_api's
  /// customer auto-sync + notification logging as a side effect server-side.
  Future<List<TopupRequest>> getPendingTopups() async {
    final data = await _post(ApiEndpoints.pendingTopups, {});

    final list = data['result'];
    if (list is! List) {
      throw const TopupRepositoryException(
        "Format respons permintaan top up tidak valid.",
      );
    }

    return list.whereType<Map<String, dynamic>>().map(TopupRequest.fromJson).toList();
  }

  /// Approves 1 pending request - customer_id & amount are looked up
  /// server-side from gameon's own record, not sent from here.
  Future<void> approveTopup({
    required int topupRequestId,
    required int paymentId,
    required String createdBy,
    required int paidBy,
  }) {
    return _post(ApiEndpoints.approveTopup, {
      "topup_request_id": topupRequestId,
      "payment_id": paymentId,
      "created_by": createdBy,
      "paid_by": paidBy,
    });
  }

  /// Locally-logged notification history - independent of getPendingTopups,
  /// stays even after a request has been approved (see topup_notification
  /// table). unreadOnly narrows it to what hasn't been seen yet.
  Future<List<TopupNotificationItem>> getNotifications({bool unreadOnly = false}) async {
    final data = await _post(ApiEndpoints.topupNotifications, {
      if (unreadOnly) "unread_only": "1",
    });

    final list = data['result'];
    if (list is! List) {
      throw const TopupRepositoryException(
        "Format respons notifikasi top up tidak valid.",
      );
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(TopupNotificationItem.fromJson)
        .toList();
  }

  /// Marks 1 notification read, or every notification when
  /// [topupNotificationId] is omitted.
  Future<void> markNotificationRead({int? topupNotificationId}) {
    return _post(ApiEndpoints.markTopupNotificationRead, {
      "topup_notification_id": ?topupNotificationId,
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
          throw const TopupRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const TopupRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw TopupRepositoryException(
          data['message']?.toString() ?? data['result']?.toString() ?? "Permintaan gagal.",
        );
      }

      return data;
    } on TopupRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw TopupRepositoryException(responseData['message'].toString());
      }
      throw const TopupRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

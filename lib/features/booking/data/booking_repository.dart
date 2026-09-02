import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/booking_request.dart';

class BookingRepositoryException implements Exception {
  final String message;

  const BookingRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Reads member self-service booking room requests via the Master/*booking*
/// endpoints, which proxy through to the gameon central server (see
/// application/libraries/Gameon.php in billing_api). There is no approve
/// action - saldo is already deducted on gameon when the booking is made.
class BookingRepository {
  final Dio _dio = Dio();

  /// Live list of bookings for [branch] (1 = Danau Sentarum, 2 = P.Aim),
  /// pulled from gameon on every call (not cached locally). Also drives
  /// billing_api's customer auto-sync + notification logging as a server-side
  /// side effect, same as [getPendingTopups].
  Future<List<BookingRequest>> getBookings({
    required int branch,
    int sinceId = 0,
  }) async {
    final data = await _post(ApiEndpoints.bookings, {
      "branch": branch,
      if (sinceId > 0) "since_id": sinceId,
    });

    final list = data['result'];
    if (list is! List) {
      throw const BookingRepositoryException(
        "Format respons daftar booking tidak valid.",
      );
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(BookingRequest.fromJson)
        .toList();
  }

  /// Locally-logged notification history - independent of getBookings, stays
  /// even after a booking has been served. unreadOnly narrows it to what
  /// hasn't been seen yet.
  Future<List<BookingNotificationItem>> getNotifications({
    required int branch,
    bool unreadOnly = false,
  }) async {
    final data = await _post(ApiEndpoints.bookingNotifications, {
      "branch": branch,
      if (unreadOnly) "unread_only": "1",
    });

    final list = data['result'];
    if (list is! List) {
      throw const BookingRepositoryException(
        "Format respons notifikasi booking tidak valid.",
      );
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(BookingNotificationItem.fromJson)
        .toList();
  }

  /// Marks 1 notification read, or every notification when
  /// [bookingNotificationId] is omitted.
  Future<void> markNotificationRead({int? bookingNotificationId}) {
    return _post(ApiEndpoints.markBookingNotificationRead, {
      "booking_notification_id": ?bookingNotificationId,
    });
  }

  /// Marks a booking as served on gameon (status -> Done) so it drops off
  /// the active list - called after the table has been opened from it.
  Future<void> confirmBooking(int bookingRequestId) {
    return _post(ApiEndpoints.confirmBooking, {
      "booking_request_id": bookingRequestId,
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
          throw const BookingRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const BookingRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw BookingRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on BookingRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw BookingRepositoryException(responseData['message'].toString());
      }
      throw const BookingRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

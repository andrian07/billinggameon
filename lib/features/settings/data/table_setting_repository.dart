import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/table_setting.dart';

class TableSettingRepositoryException implements Exception {
  final String message;

  const TableSettingRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Reads and updates physical table hardware settings via
/// Billing/setting_table and Billing/update_setting_table.
class TableSettingRepository {
  final Dio _dio = Dio();

  Future<List<TableSetting>> getTableSettings() async {
    final data = await _post(ApiEndpoints.settingTable, const {});

    final list = data['result'];
    if (list is! List) {
      throw const TableSettingRepositoryException(
        "Format respons daftar meja tidak valid.",
      );
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(TableSetting.fromJson)
        .toList();
  }

  /// Only the fields passed in are updated — omitted ones keep their
  /// current server-side value. [categoryId] is category_meja_id (an int on
  /// the backend) - see Billing_model::update_setting_table(), which treats
  /// 0/empty as "not provided" rather than "clear it" (category_meja_id is
  /// always >= 1), so there's currently no way to unassign a category here.
  Future<void> updateTableSetting({
    required int tableId,
    int? relay,
    String? number,
    int? point,
    int? categoryId,
  }) {
    final payload = <String, dynamic>{"table_id": tableId};
    if (relay != null) payload["table_relay"] = relay;
    if (number != null) payload["table_number"] = number;
    if (point != null) payload["table_point"] = point;
    if (categoryId != null) payload["table_category"] = categoryId;

    return _post(ApiEndpoints.updateSettingTable, payload);
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
          throw const TableSettingRepositoryException(
            "Format respons tidak valid.",
          );
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const TableSettingRepositoryException(
          "Format respons tidak valid.",
        );
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw TableSettingRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on TableSettingRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw TableSettingRepositoryException(
          responseData['message'].toString(),
        );
      }
      throw const TableSettingRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

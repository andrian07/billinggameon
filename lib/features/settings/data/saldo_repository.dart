import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/pagination_info.dart';
import '../../../models/saldo_option.dart';

class SaldoRepositoryException implements Exception {
  final String message;

  const SaldoRepositoryException(this.message);

  @override
  String toString() => message;
}

class SaldoListResult {
  final List<SaldoOption> items;
  final PaginationInfo pagination;

  const SaldoListResult({required this.items, required this.pagination});
}

/// Reads and manages saldo top-up packages via the Setting/*_saldo
/// endpoints. Unlike most other list endpoints in this app, saldo_list
/// nests `data`/`pagination` under `result` rather than at the top level.
class SaldoRepository {
  final Dio _dio = Dio();

  Future<SaldoListResult> getSaldos({
    required int page,
    required int perPage,
  }) async {
    final data = await _post(ApiEndpoints.saldoList, {
      "page": page,
      "per_page": perPage,
    });

    final result = data['result'];
    if (result is! Map<String, dynamic>) {
      throw const SaldoRepositoryException(
        "Format respons daftar saldo tidak valid.",
      );
    }

    final list = result['data'];
    final items = list is List
        ? list.whereType<Map<String, dynamic>>().map(SaldoOption.fromJson).toList()
        : <SaldoOption>[];

    final paginationJson = result['pagination'];
    final pagination = paginationJson is Map<String, dynamic>
        ? PaginationInfo.fromJson(paginationJson)
        : PaginationInfo.empty;

    return SaldoListResult(items: items, pagination: pagination);
  }

  /// Reads the full, unpaginated list of active saldo packages via
  /// Setting/saldo_no_pagging — used to populate the package picker in the
  /// "Tambah Saldo" (top-up) dialog on the member page.
  Future<List<SaldoOption>> getAllSaldos() async {
    final data = await _post(ApiEndpoints.saldoNoPaging, const {});

    final list = data['result'] ?? data['data'];
    if (list is! List) {
      throw const SaldoRepositoryException(
        "Format respons daftar saldo tidak valid.",
      );
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(SaldoOption.fromJson)
        .where((option) => option.active)
        .toList();
  }

  Future<void> addSaldo({
    required int nominal,
    required int price,
    required int discount,
  }) {
    return _post(ApiEndpoints.addSaldo, {
      "ms_saldo_nominal": nominal,
      "ms_saldo_price": price,
      "ms_saldo_discount": discount,
    });
  }

  /// Only the fields passed in are updated — omitted ones keep their
  /// current server-side value, so toggling [active] alone is possible.
  Future<void> editSaldo({
    required int id,
    int? nominal,
    int? price,
    int? discount,
    bool? active,
  }) {
    return _post(ApiEndpoints.editSaldo, {
      "ms_saldo_id": id,
      if (nominal != null) "ms_saldo_nominal": nominal,
      if (price != null) "ms_saldo_price": price,
      if (discount != null) "ms_saldo_discount": discount,
      if (active != null) "ms_saldo_active": active ? "Y" : "N",
    });
  }

  Future<void> deleteSaldo(int id) {
    return _post(ApiEndpoints.deleteSaldo, {"ms_saldo_id": id});
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
          throw const SaldoRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const SaldoRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw SaldoRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on SaldoRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw SaldoRepositoryException(responseData['message'].toString());
      }
      throw const SaldoRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

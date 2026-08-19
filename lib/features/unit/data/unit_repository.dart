import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/unit.dart';

class UnitRepositoryException implements Exception {
  final String message;

  const UnitRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Reads and manages product units via the Master/*_unit endpoints.
class UnitRepository {
  final Dio _dio = Dio();

  Future<List<Unit>> getUnits() async {
    final data = await _post(ApiEndpoints.unitList, {
      "page": 1,
      "per_page": 1000,
    });

    final list = data['data'];
    if (list is! List) {
      throw const UnitRepositoryException(
        "Format respons daftar unit tidak valid.",
      );
    }

    return list.whereType<Map<String, dynamic>>().map(_fromJson).toList();
  }

  Future<void> addUnit(String name) {
    return _post(ApiEndpoints.addUnit, {"unit_name": name.trim()});
  }

  Future<void> editUnit({required int id, required String name}) {
    return _post(ApiEndpoints.editUnit, {
      "unit_id": id,
      "unit_name": name.trim(),
    });
  }

  Future<void> deleteUnit(int id) {
    return _post(ApiEndpoints.deleteUnit, {"unit_id": id});
  }

  Unit _fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return Unit(
      id: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      name: json['name']?.toString() ?? "",
    );
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
          throw const UnitRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const UnitRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw UnitRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on UnitRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw UnitRepositoryException(responseData['message'].toString());
      }
      throw const UnitRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/pagination_info.dart';
import '../../../models/point_exchange.dart';

class PointExchangeRepositoryException implements Exception {
  final String message;

  const PointExchangeRepositoryException(this.message);

  @override
  String toString() => message;
}

/// An image picked in the UI, ready to be attached to a multipart request.
class PointExchangeImageInput {
  final String filename;
  final List<int> bytes;

  const PointExchangeImageInput({required this.filename, required this.bytes});
}

class PointExchangeListResult {
  final List<PointExchange> items;
  final PaginationInfo pagination;

  const PointExchangeListResult({
    required this.items,
    required this.pagination,
  });
}

/// Reads and manages point-exchange rewards via the Setting/*_point_exchange
/// endpoints. add_point_exchange/edit_point_exchange take multipart/form-data
/// (they accept an image upload); delete_point_exchange soft-deletes (sets
/// ms_point_exchange_active = 'N') rather than removing the row.
class PointExchangeRepository {
  final Dio _dio = Dio();

  Future<PointExchangeListResult> getPointExchanges({
    required int page,
    required int perPage,
  }) async {
    final data = await _post(ApiEndpoints.pointExchangeList, {
      "page": page,
      "per_page": perPage,
    });

    final list = data['data'];
    if (list is! List) {
      throw const PointExchangeRepositoryException(
        "Format respons daftar tukar point tidak valid.",
      );
    }

    final items = list
        .whereType<Map<String, dynamic>>()
        .map(PointExchange.fromJson)
        .toList();

    final paginationJson = data['pagination'];
    final pagination = paginationJson is Map<String, dynamic>
        ? PaginationInfo.fromJson(paginationJson)
        : PaginationInfo.empty;

    return PointExchangeListResult(items: items, pagination: pagination);
  }

  Future<void> addPointExchange({
    required String name,
    required int point,
    String? description,
    PointExchangeImageInput? image,
  }) async {
    final formData = FormData.fromMap({
      "ms_point_exchange_name": name.trim(),
      "ms_point_exchange_point": "$point",
      if (description != null) "ms_point_exchange_desc": description.trim(),
      if (image != null)
        "ms_point_exchange_image": MultipartFile.fromBytes(
          image.bytes,
          filename: image.filename,
        ),
    });

    await _postForm(ApiEndpoints.addPointExchange, formData);
  }

  /// Only the fields passed in are updated — omitted ones (including the
  /// image, when [image] is null) keep their current server-side value.
  Future<void> editPointExchange({
    required int id,
    String? name,
    int? point,
    String? description,
    PointExchangeImageInput? image,
  }) async {
    final formData = FormData.fromMap({
      "ms_point_exchange_id": "$id",
      if (name != null) "ms_point_exchange_name": name.trim(),
      if (point != null) "ms_point_exchange_point": "$point",
      if (description != null) "ms_point_exchange_desc": description.trim(),
      if (image != null)
        "ms_point_exchange_image": MultipartFile.fromBytes(
          image.bytes,
          filename: image.filename,
        ),
    });

    await _postForm(ApiEndpoints.editPointExchange, formData);
  }

  Future<void> deletePointExchange(int id) {
    return _post(ApiEndpoints.deletePointExchange, {
      "ms_point_exchange_id": id,
    });
  }

  Future<Map<String, dynamic>> _postForm(String url, FormData formData) async {
    try {
      final response = await _dio.post(url, data: formData);
      return _parseResponse(response.data);
    } on PointExchangeRepositoryException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(url, data: payload);
      return _parseResponse(response.data);
    } on PointExchangeRepositoryException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Map<String, dynamic> _parseResponse(dynamic data) {
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        throw const PointExchangeRepositoryException(
          "Format respons tidak valid.",
        );
      }
    }
    if (data is! Map<String, dynamic>) {
      throw const PointExchangeRepositoryException(
        "Format respons tidak valid.",
      );
    }

    final code = data['code'];
    if (code != null && code.toString() != "200") {
      throw PointExchangeRepositoryException(
        data['message']?.toString() ??
            data['result']?.toString() ??
            "Permintaan gagal.",
      );
    }

    return data;
  }

  PointExchangeRepositoryException _mapDioError(DioException e) {
    final responseData = e.response?.data;
    if (responseData is Map && responseData['message'] != null) {
      return PointExchangeRepositoryException(
        responseData['message'].toString(),
      );
    }
    return const PointExchangeRepositoryException(
      "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
    );
  }
}

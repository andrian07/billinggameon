import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/product_category.dart';

class CategoryRepositoryException implements Exception {
  final String message;

  const CategoryRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Reads and manages product categories via the Master/*_category endpoints.
class CategoryRepository {
  final Dio _dio = Dio();

  Future<List<ProductCategory>> getCategories() async {
    final data = await _post(ApiEndpoints.categoryList, {
      "page": 1,
      "per_page": 1000,
    });

    final list = data['data'];
    if (list is! List) {
      throw const CategoryRepositoryException(
        "Format respons daftar kategori tidak valid.",
      );
    }

    return list.whereType<Map<String, dynamic>>().map(_fromJson).toList();
  }

  Future<void> addCategory(String name) {
    return _post(ApiEndpoints.addCategory, {"category_name": name.trim()});
  }

  Future<void> editCategory({required int id, required String name}) {
    return _post(ApiEndpoints.editCategory, {
      "category_id": id,
      "category_name": name.trim(),
    });
  }

  Future<void> deleteCategory(int id) {
    return _post(ApiEndpoints.deleteCategory, {"category_id": id});
  }

  ProductCategory _fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return ProductCategory(
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
          throw const CategoryRepositoryException(
            "Format respons tidak valid.",
          );
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const CategoryRepositoryException(
          "Format respons tidak valid.",
        );
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw CategoryRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on CategoryRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw CategoryRepositoryException(responseData['message'].toString());
      }
      throw const CategoryRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

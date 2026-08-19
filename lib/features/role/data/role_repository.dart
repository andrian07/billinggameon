import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/access_menu.dart';
import '../../../models/role.dart';
import '../../../models/role_menu_access.dart';

class RoleRepositoryException implements Exception {
  final String message;

  const RoleRepositoryException(this.message);

  @override
  String toString() => message;
}

/// Manages roles and their per-menu permissions via the Access/* endpoints.
class RoleRepository {
  final Dio _dio = Dio();

  Future<List<Role>> getRoles() async {
    final data = await _post(ApiEndpoints.roleListNoPaging, const {});

    final result = data['result'];
    if (result is! List) {
      throw const RoleRepositoryException(
        "Format respons daftar role tidak valid.",
      );
    }

    return result.whereType<Map<String, dynamic>>().map(Role.fromJson).toList();
  }

  Future<List<AccessMenu>> getMenus() async {
    final data = await _post(ApiEndpoints.menuListNoPaging, const {});

    final result = data['result'];
    if (result is! List) {
      throw const RoleRepositoryException(
        "Format respons daftar menu tidak valid.",
      );
    }

    return result
        .whereType<Map<String, dynamic>>()
        .map(AccessMenu.fromJson)
        .toList();
  }

  Future<int> addRole(String name) async {
    final data = await _post(ApiEndpoints.addRole, {"role_name": name});

    final rawId = data['role_id'];
    return rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "") ?? 0;
  }

  Future<List<RoleMenuAccess>> getRoleAccess(int roleId) async {
    final data = await _post(ApiEndpoints.roleAccess, {"role_id": roleId});

    final result = data['result'];
    if (result is! List) return const [];

    return result
        .whereType<Map<String, dynamic>>()
        .map(RoleMenuAccess.fromJson)
        .toList();
  }

  Future<void> updateRoleAccess(
    int roleId,
    List<RoleMenuAccess> access,
  ) {
    return _post(ApiEndpoints.updateRoleAccess, {
      "role_id": roleId,
      "access": [
        for (final entry in access)
          {
            "menu_id": entry.menuId,
            "can_view": entry.canView ? "Y" : "N",
            "can_add": entry.canAdd ? "Y" : "N",
            "can_edit": entry.canEdit ? "Y" : "N",
            "can_delete": entry.canDelete ? "Y" : "N",
          },
      ],
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
          throw const RoleRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const RoleRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw RoleRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on RoleRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw RoleRepositoryException(responseData['message'].toString());
      }
      throw const RoleRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

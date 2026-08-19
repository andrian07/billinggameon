import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/app_user.dart';
import '../../../models/pagination_info.dart';
import '../../role/data/role_repository.dart';

class UserRepositoryException implements Exception {
  final String message;

  const UserRepositoryException(this.message);

  @override
  String toString() => message;
}

class UserListResult {
  final List<AppUser> users;
  final PaginationInfo pagination;

  const UserListResult({required this.users, required this.pagination});
}

/// A downloaded user QR code PNG, ready to be shown/saved.
class UserQrCode {
  final String filename;
  final Uint8List bytes;

  const UserQrCode({required this.filename, required this.bytes});
}

/// Reads and manages user accounts via the Master/* endpoints.
class UserRepository {
  final Dio _dio = Dio();
  final _roleRepository = RoleRepository();

  Future<UserListResult> getUsers({
    required int page,
    required int perPage,
  }) async {
    final data = await _post(ApiEndpoints.userList, {
      "page": "$page",
      "per_page": "$perPage",
    });

    final list = data['data'];
    if (list is! List) {
      throw const UserRepositoryException(
        "Format respons daftar pengguna tidak valid.",
      );
    }

    final rows = list.whereType<Map<String, dynamic>>().toList();
    final roleNames = await _fetchRoleNames();

    final users = rows.map((json) {
      final roleId = int.tryParse(json['role']?.toString() ?? "");
      return AppUser.fromJson(json, roleName: roleNames[roleId]);
    }).toList();

    final paginationJson = data['pagination'];
    final pagination = paginationJson is Map<String, dynamic>
        ? PaginationInfo.fromJson(paginationJson)
        : PaginationInfo.empty;

    return UserListResult(users: users, pagination: pagination);
  }

  Future<Map<int, String>> _fetchRoleNames() async {
    try {
      final roles = await _roleRepository.getRoles();
      return {for (final role in roles) role.id: role.name};
    } catch (_) {
      return const {};
    }
  }

  Future<void> addUser({
    required String username,
    required String password,
    required int roleId,
  }) {
    return _post(ApiEndpoints.addUser, {
      "username": username,
      "password": password,
      "role": "$roleId",
    });
  }

  Future<void> editUser({
    required int userId,
    required String username,
    String? password,
    required int roleId,
  }) {
    return _post(ApiEndpoints.editUser, {
      "user_id": "$userId",
      "username": username,
      if (password != null && password.isNotEmpty) "password": password,
      "role": "$roleId",
    });
  }

  Future<void> deleteUser(int userId) {
    return _post(ApiEndpoints.deleteUser, {"user_id": "$userId"});
  }

  Future<void> resetPassword(int userId) {
    return _post(ApiEndpoints.resetPasswordUser, {"user_id": "$userId"});
  }

  /// Fetches a user's login QR code (PNG) via Master/user_qrcode/{user_id}
  /// — shown/saved from the "Lihat QR" action on the users page.
  Future<UserQrCode> getUserQrCode(int userId) async {
    try {
      final response = await _dio.get(
        "${ApiEndpoints.userQrCode}/$userId",
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data as List<int>);
      final filename =
          _filenameFromContentDisposition(
            response.headers.value('content-disposition'),
          ) ??
          "qrcode_user_$userId.png";

      return UserQrCode(filename: filename, bytes: bytes);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is List<int>) {
        String? message;
        try {
          final decoded = jsonDecode(utf8.decode(responseData));
          if (decoded is Map && decoded['result'] != null) {
            message = decoded['result'].toString();
          }
        } catch (_) {
          // Body wasn't JSON — fall through to the generic message below.
        }
        if (message != null) throw UserRepositoryException(message);
      }
      throw const UserRepositoryException(
        "Tidak dapat memuat QR code. Periksa koneksi Anda.",
      );
    }
  }

  String? _filenameFromContentDisposition(String? header) {
    if (header == null) return null;
    final match = RegExp(
      r'''filename\*?=(?:UTF-8'')?"?([^";]+)"?''',
    ).firstMatch(header);
    return match?.group(1)?.trim();
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
          throw const UserRepositoryException("Format respons tidak valid.");
        }
      }
      if (data is! Map<String, dynamic>) {
        throw const UserRepositoryException("Format respons tidak valid.");
      }

      final code = data['code'];
      if (code != null && code.toString() != "200") {
        throw UserRepositoryException(
          data['message']?.toString() ??
              data['result']?.toString() ??
              "Permintaan gagal.",
        );
      }

      return data;
    } on UserRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw UserRepositoryException(responseData['message'].toString());
      }
      throw const UserRepositoryException(
        "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
      );
    }
  }
}

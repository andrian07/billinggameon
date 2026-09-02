import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../models/game.dart';
import '../../../models/pagination_info.dart';

class GameRepositoryException implements Exception {
  final String message;

  const GameRepositoryException(this.message);

  @override
  String toString() => message;
}

/// An image picked in the UI, ready to be attached to a multipart request.
class GameImageInput {
  final String filename;
  final List<int> bytes;

  const GameImageInput({required this.filename, required this.bytes});
}

class GameListResult {
  final List<Game> items;
  final PaginationInfo pagination;

  const GameListResult({required this.items, required this.pagination});
}

/// Reads and manages the game catalog via the Setting/*_game endpoints.
/// add_game/edit_game take multipart/form-data (image upload); delete_game
/// soft-deletes (sets ms_game_active = 'N').
class GameRepository {
  final Dio _dio = Dio();

  Future<GameListResult> getGames({
    required int page,
    required int perPage,
  }) async {
    final data = await _post(ApiEndpoints.gameList, {
      "page": page,
      "per_page": perPage,
    });

    final list = data['data'];
    if (list is! List) {
      throw const GameRepositoryException(
        "Format respons daftar game tidak valid.",
      );
    }

    final items = list
        .whereType<Map<String, dynamic>>()
        .map(Game.fromJson)
        .toList();

    final paginationJson = data['pagination'];
    final pagination = paginationJson is Map<String, dynamic>
        ? PaginationInfo.fromJson(paginationJson)
        : PaginationInfo.empty;

    return GameListResult(items: items, pagination: pagination);
  }

  Future<void> addGame({
    required String name,
    required List<int> branchIds,
    required List<String> consoles,
    required List<int> roomIds,
    String? description,
    GameImageInput? image,
  }) async {
    final formData = FormData.fromMap({
      "ms_game_name": name.trim(),
      "ms_game_branch": branchIds.join(","),
      "ms_game_console": consoles.join(","),
      "ms_game_room_ids": roomIds.join(","),
      if (description != null) "ms_game_desc": description.trim(),
      if (image != null)
        "ms_game_image": MultipartFile.fromBytes(
          image.bytes,
          filename: image.filename,
        ),
    });

    await _postForm(ApiEndpoints.addGame, formData);
  }

  /// Only the fields passed in are updated — omitted ones (including the
  /// image, when [image] is null) keep their current server-side value.
  Future<void> editGame({
    required int id,
    String? name,
    List<int>? branchIds,
    List<String>? consoles,
    List<int>? roomIds,
    String? description,
    GameImageInput? image,
  }) async {
    final formData = FormData.fromMap({
      "ms_game_id": "$id",
      if (name != null) "ms_game_name": name.trim(),
      if (branchIds != null) "ms_game_branch": branchIds.join(","),
      if (consoles != null) "ms_game_console": consoles.join(","),
      if (roomIds != null) "ms_game_room_ids": roomIds.join(","),
      if (description != null) "ms_game_desc": description.trim(),
      if (image != null)
        "ms_game_image": MultipartFile.fromBytes(
          image.bytes,
          filename: image.filename,
        ),
    });

    await _postForm(ApiEndpoints.editGame, formData);
  }

  Future<void> deleteGame(int id) {
    return _post(ApiEndpoints.deleteGame, {"ms_game_id": id});
  }

  Future<Map<String, dynamic>> _postForm(String url, FormData formData) async {
    try {
      final response = await _dio.post(url, data: formData);
      return _parseResponse(response.data);
    } on GameRepositoryException {
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
    } on GameRepositoryException {
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
        throw const GameRepositoryException("Format respons tidak valid.");
      }
    }
    if (data is! Map<String, dynamic>) {
      throw const GameRepositoryException("Format respons tidak valid.");
    }

    final code = data['code'];
    if (code != null && code.toString() != "200") {
      throw GameRepositoryException(
        data['message']?.toString() ??
            data['result']?.toString() ??
            "Permintaan gagal.",
      );
    }

    return data;
  }

  GameRepositoryException _mapDioError(DioException e) {
    final responseData = e.response?.data;
    if (responseData is Map && responseData['message'] != null) {
      return GameRepositoryException(responseData['message'].toString());
    }
    return const GameRepositoryException(
      "Tidak dapat terhubung ke server. Periksa koneksi Anda.",
    );
  }
}

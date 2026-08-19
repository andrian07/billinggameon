class AppUser {
  final int id;
  final String username;
  final int? roleId;
  final String? roleName;

  const AppUser({
    required this.id,
    required this.username,
    this.roleId,
    this.roleName,
  });

  /// Role id 1 is reserved for the built-in superadmin account — it's
  /// created outside Access/add_role and can't be edited/deleted from here.
  bool get isSuperadmin => roleId == 1;

  factory AppUser.fromJson(Map<String, dynamic> json, {String? roleName}) {
    final rawId = json['id'];
    return AppUser(
      id: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      username: json['name']?.toString() ?? "",
      roleId: int.tryParse(json['role']?.toString() ?? ""),
      roleName: roleName,
    );
  }

  AppUser copyWith({String? username, int? roleId, String? roleName}) {
    return AppUser(
      id: id,
      username: username ?? this.username,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
    );
  }
}

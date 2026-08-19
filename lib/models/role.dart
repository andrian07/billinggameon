/// A user role (e.g. Superadmin, Supervisor, Kasir) read via
/// Access/role_list_no_pagging — roles are data-driven, created through
/// Access/add_role, rather than a fixed set.
class Role {
  final int id;
  final String name;
  final bool active;

  const Role({required this.id, required this.name, this.active = true});

  factory Role.fromJson(Map<String, dynamic> json) {
    final rawId = json['role_id'] ?? json['id'];
    final rawActive = json['role_active'] ?? json['active'];

    return Role(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "") ?? 0,
      name: (json['role_name'] ?? json['name'])?.toString() ?? "",
      active: (rawActive?.toString().toUpperCase() ?? "Y") == "Y",
    );
  }
}

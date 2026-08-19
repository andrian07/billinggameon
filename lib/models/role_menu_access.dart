/// A role's permission flags for one menu — read from/written to
/// Access/role_access and Access/update_role_access. Fields are mutable
/// since the access-matrix editor toggles them directly on the instances it
/// holds, one per menu, rather than rebuilding immutable copies per tap.
class RoleMenuAccess {
  final int menuId;
  bool canView;
  bool canAdd;
  bool canEdit;
  bool canDelete;

  RoleMenuAccess({
    required this.menuId,
    this.canView = false,
    this.canAdd = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory RoleMenuAccess.fromJson(Map<String, dynamic> json) {
    bool asYN(dynamic value) => value?.toString().toUpperCase() == "Y";
    final rawId = json['menu_id'];

    return RoleMenuAccess(
      menuId: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "") ?? 0,
      canView: asYN(json['can_view']),
      canAdd: asYN(json['can_add']),
      canEdit: asYN(json['can_edit']),
      canDelete: asYN(json['can_delete']),
    );
  }
}

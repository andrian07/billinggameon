/// One entry of the app's menu tree, read via Access/menu_list_no_pagging —
/// the fixed set of screens that role permissions can be granted against.
class AccessMenu {
  final int id;
  final String code;
  final String name;

  const AccessMenu({required this.id, required this.code, required this.name});

  factory AccessMenu.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['menu_id'];

    return AccessMenu(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "") ?? 0,
      code: (json['code'] ?? json['menu_code'])?.toString() ?? "",
      name: (json['name'] ?? json['menu_name'])?.toString() ?? "",
    );
  }
}

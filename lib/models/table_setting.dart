/// A physical table's hardware/config settings, managed via
/// Billing/setting_table and Billing/update_setting_table.
class TableSetting {
  final int id;
  final int relay;
  final String number;
  final int point;
  final String? category;

  const TableSetting({
    required this.id,
    required this.relay,
    required this.number,
    required this.point,
    this.category,
  });

  factory TableSetting.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    final category = json['table_category']?.toString();

    return TableSetting(
      id: asInt(json['table_id']),
      relay: asInt(json['table_relay']),
      number: json['table_number']?.toString() ?? "",
      point: asInt(json['table_point']),
      category: (category == null || category.isEmpty) ? null : category,
    );
  }

  /// Unlike the other fields, [category] is genuinely optional (a table can
  /// have none), so this always sets it to whatever is passed — including
  /// null, to actually clear it — rather than falling back to the current
  /// value like the other params do.
  TableSetting copyWith({
    int? relay,
    String? number,
    int? point,
    String? category,
  }) {
    return TableSetting(
      id: id,
      relay: relay ?? this.relay,
      number: number ?? this.number,
      point: point ?? this.point,
      category: category,
    );
  }
}

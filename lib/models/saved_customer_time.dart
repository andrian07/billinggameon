import '../core/utils/formatters.dart';

/// A customer's banked play time for a table's category, returned by
/// Master/get_save_customer_time.
class SavedCustomerTime {
  final int customerId;
  final String customerName;
  final String tableId;
  final int categoryMejaId;
  final String categoryMejaName;
  final Duration timeRemaining;

  const SavedCustomerTime({
    required this.customerId,
    required this.customerName,
    required this.tableId,
    required this.categoryMejaId,
    required this.categoryMejaName,
    required this.timeRemaining,
  });

  bool get hasBalance => timeRemaining > Duration.zero;

  factory SavedCustomerTime.fromJson(Map<String, dynamic> json) {
    final rawCustomerId = json['customer_id'];
    final rawCategoryId = json['category_meja_id'];

    return SavedCustomerTime(
      customerId: rawCustomerId is int
          ? rawCustomerId
          : int.tryParse(rawCustomerId.toString()) ?? 0,
      customerName: json['customer_name']?.toString() ?? "",
      tableId: json['table_id']?.toString() ?? "",
      categoryMejaId: rawCategoryId is int
          ? rawCategoryId
          : int.tryParse(rawCategoryId.toString()) ?? 0,
      categoryMejaName: json['category_meja_name']?.toString() ?? "",
      timeRemaining:
          parseApiDuration(json['time_remaining']?.toString()) ??
          Duration.zero,
    );
  }
}

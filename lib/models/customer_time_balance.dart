import '../core/utils/formatters.dart';

/// One row of a customer's banked play time for a table category, returned
/// by Master/get_time_per_customer.
class CustomerTimeBalance {
  final int id;
  final int customerId;
  final String customerName;
  final int categoryMejaId;
  final String categoryMejaName;
  final Duration timeRemaining;
  final DateTime? updatedAt;

  const CustomerTimeBalance({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.categoryMejaId,
    required this.categoryMejaName,
    required this.timeRemaining,
    this.updatedAt,
  });

  factory CustomerTimeBalance.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    return CustomerTimeBalance(
      id: asInt(json['id']),
      customerId: asInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? "",
      categoryMejaId: asInt(json['category_meja_id']),
      categoryMejaName: json['category_meja_name']?.toString() ?? "",
      timeRemaining:
          parseApiDuration(json['time_remaining']?.toString()) ??
          Duration.zero,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ""),
    );
  }
}

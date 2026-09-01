class TopupRequest {
  final int topupRequestId;
  final int customerId;
  final String customerName;
  final String customerPhone;
  final int amount;
  final String paymentMethod;
  final DateTime? createdAt;

  const TopupRequest({
    required this.topupRequestId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    required this.paymentMethod,
    this.createdAt,
  });

  factory TopupRequest.fromJson(Map<String, dynamic> json) {
    final rawId = json['topup_request_id'];
    final rawCustomerId = json['customer_id'];
    final rawAmount = json['amount'];

    return TopupRequest(
      topupRequestId: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      customerId: rawCustomerId is int
          ? rawCustomerId
          : int.tryParse(rawCustomerId.toString()) ?? 0,
      customerName: json['customer_name']?.toString() ?? "",
      customerPhone: json['customer_phone']?.toString() ?? "",
      amount: rawAmount is int ? rawAmount : int.tryParse(rawAmount.toString()) ?? 0,
      paymentMethod: json['payment_method']?.toString() ?? "",
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ""),
    );
  }
}

class TopupNotificationItem {
  final int id;
  final int topupRequestId;
  final int customerId;
  final String customerName;
  final int amount;
  final String paymentMethod;
  final bool isRead;
  final DateTime? createdAt;

  const TopupNotificationItem({
    required this.id,
    required this.topupRequestId,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.paymentMethod,
    required this.isRead,
    this.createdAt,
  });

  factory TopupNotificationItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawRequestId = json['topup_request_id'];
    final rawCustomerId = json['customer_id'];
    final rawAmount = json['amount'];

    return TopupNotificationItem(
      id: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      topupRequestId: rawRequestId is int
          ? rawRequestId
          : int.tryParse(rawRequestId.toString()) ?? 0,
      customerId: rawCustomerId is int
          ? rawCustomerId
          : int.tryParse(rawCustomerId.toString()) ?? 0,
      customerName: json['customer_name']?.toString() ?? "",
      amount: rawAmount is int ? rawAmount : int.tryParse(rawAmount.toString()) ?? 0,
      paymentMethod: json['payment_method']?.toString() ?? "",
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ""),
    );
  }
}

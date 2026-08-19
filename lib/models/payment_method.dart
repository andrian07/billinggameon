/// An active payment method (ms_payment) read via Master/get_payment_list,
/// e.g. CASH, Transfer, Qris, EDC.
class PaymentMethod {
  final int id;
  final String name;

  const PaymentMethod({required this.id, required this.name});

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: int.tryParse(json['id']?.toString() ?? "") ?? 0,
      name: json['name']?.toString() ?? "",
    );
  }
}

/// A top-up saldo package (nominal credited vs. price charged, with an
/// optional discount), managed via the Setting/*_saldo endpoints.
class SaldoOption {
  final int id;
  final int nominal;
  final int price;
  final int discount;
  final bool active;

  const SaldoOption({
    required this.id,
    required this.nominal,
    required this.price,
    required this.discount,
    required this.active,
  });

  factory SaldoOption.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    return SaldoOption(
      id: asInt(json['id']),
      nominal: asInt(json['nominal']),
      price: asInt(json['price']),
      discount: asInt(json['discount']),
      active: json['active']?.toString().toUpperCase() != "N",
    );
  }
}

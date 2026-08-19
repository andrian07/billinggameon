class PriceSetting {
  final int id;
  final String day;
  final int hour;
  final int price;

  const PriceSetting({
    required this.id,
    required this.day,
    required this.hour,
    required this.price,
  });

  PriceSetting copyWith({int? price}) {
    return PriceSetting(
      id: id,
      day: day,
      hour: hour,
      price: price ?? this.price,
    );
  }

  factory PriceSetting.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    return PriceSetting(
      id: asInt(json['id']),
      day: json['days']?.toString() ?? "",
      hour: asInt(json['time']),
      price: asInt(json['price']),
    );
  }
}

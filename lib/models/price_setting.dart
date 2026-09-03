/// Harga per slot hari+jam. Backend (ms_master_price) menyimpan 5 tingkat harga
/// (price..price_5, dipilih lewat category_meja_price di kategori meja). UI
/// Setting > Harga menampilkan & mengedit kelima tingkat (Harga 1..5).
class PriceSetting {
  final int id;
  final String day;
  final int hour;
  final int price;
  final int price2;
  final int price3;
  final int price4;
  final int price5;

  const PriceSetting({
    required this.id,
    required this.day,
    required this.hour,
    required this.price,
    required this.price2,
    required this.price3,
    required this.price4,
    required this.price5,
  });

  PriceSetting copyWith({
    int? price,
    int? price2,
    int? price3,
    int? price4,
    int? price5,
  }) {
    return PriceSetting(
      id: id,
      day: day,
      hour: hour,
      price: price ?? this.price,
      price2: price2 ?? this.price2,
      price3: price3 ?? this.price3,
      price4: price4 ?? this.price4,
      price5: price5 ?? this.price5,
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
      price2: asInt(json['price_2']),
      price3: asInt(json['price_3']),
      price4: asInt(json['price_4']),
      price5: asInt(json['price_5']),
    );
  }
}

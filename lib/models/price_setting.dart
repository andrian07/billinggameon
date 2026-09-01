/// Harga per slot hari+jam. Backend (ms_master_price) sebenarnya menyimpan
/// sampai 5 tingkat harga (price..price_5, dipilih lewat category_meja_price
/// di kategori meja), tapi UI Setting > Harga hanya menampilkan & mengedit
/// 3 tingkat pertama (Harga 1/2/3).
class PriceSetting {
  final int id;
  final String day;
  final int hour;
  final int price;
  final int price2;
  final int price3;

  const PriceSetting({
    required this.id,
    required this.day,
    required this.hour,
    required this.price,
    required this.price2,
    required this.price3,
  });

  PriceSetting copyWith({int? price, int? price2, int? price3}) {
    return PriceSetting(
      id: id,
      day: day,
      hour: hour,
      price: price ?? this.price,
      price2: price2 ?? this.price2,
      price3: price3 ?? this.price3,
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
    );
  }
}

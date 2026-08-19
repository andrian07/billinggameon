enum PromoType {
  percentage,
  fixed;

  String get label => this == PromoType.percentage ? "Diskon %" : "Fix";

  String get apiValue => this == PromoType.percentage ? "Diskon" : "Fix";

  static PromoType fromApiValue(String value) {
    return value.trim().toLowerCase() == "fix"
        ? PromoType.fixed
        : PromoType.percentage;
  }
}

class Promo {
  final int id;
  final String name;
  final PromoType type;
  final int value;

  /// Hours granted when this promo is picked while starting a Timer session
  /// — only meaningful for [PromoType.fixed]. Null means no fixed duration
  /// is configured (or the promo is a percentage discount).
  final int? hourGained;

  const Promo({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.hourGained,
  });

  factory Promo.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawValue = json['value'];
    final rawHour = json['hour'];

    return Promo(
      id: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      name: json['name']?.toString() ?? "",
      type: PromoType.fromApiValue(json['tipe']?.toString() ?? ""),
      value: rawValue is int
          ? rawValue
          : int.tryParse(rawValue.toString()) ?? 0,
      hourGained: rawHour is int
          ? rawHour
          : int.tryParse(rawHour?.toString() ?? ""),
    );
  }
}

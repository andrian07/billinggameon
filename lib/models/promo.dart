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

  /// Days of week this promo may be used (1=Senin..7=Minggu, ISO weekday —
  /// matches PHP's date('N') on the backend). Empty/null means every day.
  final List<int>? validDays;

  /// Hour-of-day window (0-24) this promo may be used within — always both
  /// set together or both null (see Master::_parse_promo_schedule on the
  /// backend). A promo with a window can only be used for Timer sessions,
  /// since a Reguler (open-ended) session has no known end time to check
  /// against the window up front.
  final int? validTimeStart;
  final int? validTimeEnd;

  const Promo({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.hourGained,
    this.validDays,
    this.validTimeStart,
    this.validTimeEnd,
  });

  bool get hasDayRestriction => validDays != null && validDays!.isNotEmpty;

  bool get hasTimeWindow => validTimeStart != null && validTimeEnd != null;

  factory Promo.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawValue = json['value'];
    final rawHour = json['hour'];
    final rawDays = json['valid_days']?.toString();
    final rawStart = json['valid_time_start'];
    final rawEnd = json['valid_time_end'];

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
      validDays: (rawDays != null && rawDays.isNotEmpty)
          ? rawDays
              .split(',')
              .map((d) => int.tryParse(d.trim()))
              .whereType<int>()
              .toList()
          : null,
      validTimeStart: rawStart is int
          ? rawStart
          : int.tryParse(rawStart?.toString() ?? ""),
      validTimeEnd: rawEnd is int
          ? rawEnd
          : int.tryParse(rawEnd?.toString() ?? ""),
    );
  }
}

/// Senin..Minggu labels, keyed by ISO weekday (1=Senin..7=Minggu) to match
/// [Promo.validDays] and the backend's date('N').
const Map<int, String> weekdayLabels = {
  1: "Senin",
  2: "Selasa",
  3: "Rabu",
  4: "Kamis",
  5: "Jumat",
  6: "Sabtu",
  7: "Minggu",
};

/// A reward redeemable with member points, managed via the
/// Setting/*_point_exchange endpoints. Only active rewards
/// (ms_point_exchange_active = 'Y') are ever returned by the list endpoint.
class PointExchange {
  final int id;
  final String name;
  final int point;
  final String description;
  final String imageUrl;

  const PointExchange({
    required this.id,
    required this.name,
    required this.point,
    required this.description,
    required this.imageUrl,
  });

  factory PointExchange.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    return PointExchange(
      id: asInt(json['id']),
      name: json['name']?.toString() ?? "",
      point: asInt(json['point']),
      description: json['desc']?.toString() ?? "",
      imageUrl: json['image_url']?.toString() ?? "",
    );
  }
}

class Product {
  final int id;
  final String code;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final int? unitId;
  final String? unitName;
  final int price;
  final int cogs;
  final int stock;
  final bool reduceStock;
  final String image;
  final String imageUrl;

  const Product({
    required this.id,
    required this.code,
    required this.name,
    this.categoryId,
    this.categoryName,
    this.unitId,
    this.unitName,
    required this.price,
    required this.cogs,
    required this.stock,
    required this.reduceStock,
    required this.image,
    required this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    final categoryId = int.tryParse(json['category_id']?.toString() ?? "");
    final unitId = int.tryParse(json['unit_id']?.toString() ?? "");

    return Product(
      id: asInt(json['id']),
      code: json['code']?.toString() ?? "",
      name: json['name']?.toString() ?? "",
      categoryId: (categoryId != null && categoryId != 0) ? categoryId : null,
      categoryName: json['category_name']?.toString(),
      unitId: (unitId != null && unitId != 0) ? unitId : null,
      unitName: json['unit_name']?.toString(),
      price: asInt(json['price']),
      cogs: asInt(json['cogs']),
      stock: asInt(json['stock']),
      reduceStock: json['reduce_stock']?.toString().toUpperCase() == "Y",
      image: json['image']?.toString() ?? "",
      imageUrl: json['image_url']?.toString() ?? "",
    );
  }
}

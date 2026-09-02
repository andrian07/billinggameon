/// Promo khusus transaksi cafe/POS. Berbeda dari [Promo] (billing): promo cafe
/// punya HARGA PROMO tetap dan daftar produk yang dicakup. Saat dipakai di POS,
/// subtotal gabungan produk-produk itu di keranjang di-reprice jadi [price].
class CafePromoItem {
  final int productId;
  final String productName;
  final int productPrice;

  const CafePromoItem({
    required this.productId,
    required this.productName,
    required this.productPrice,
  });

  factory CafePromoItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? "") ?? 0;
    return CafePromoItem(
      productId: asInt(json['product_id']),
      productName: json['product_name']?.toString() ?? "",
      productPrice: asInt(json['product_price']),
    );
  }
}

class CafePromo {
  final int id;
  final String name;
  final int price;
  final bool active;
  final List<int> productIds;
  final List<CafePromoItem> items;

  const CafePromo({
    required this.id,
    required this.name,
    required this.price,
    required this.active,
    required this.productIds,
    required this.items,
  });

  factory CafePromo.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? "") ?? 0;

    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(CafePromoItem.fromJson)
              .toList()
        : <CafePromoItem>[];

    final rawIds = json['product_ids'];
    final ids = rawIds is List
        ? rawIds
              .map((e) => int.tryParse(e.toString()))
              .whereType<int>()
              .toList()
        : items.map((i) => i.productId).toList();

    return CafePromo(
      id: asInt(json['id']),
      name: json['name']?.toString() ?? "",
      price: asInt(json['price']),
      active: (json['active']?.toString().toUpperCase() ?? "Y") == "Y",
      productIds: ids,
      items: items,
    );
  }
}

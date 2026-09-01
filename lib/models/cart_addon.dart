import 'product.dart';

/// An additional item (e.g. Telur) attached to a [CartItem] line (e.g.
/// Indomie) — its own product with its own quantity, priced and stocked
/// independently of the parent item's quantity.
class CartAddon {
  final Product product;
  final int quantity;

  const CartAddon({required this.product, required this.quantity});

  int get lineTotal => product.price * quantity;

  CartAddon copyWith({int? quantity}) {
    return CartAddon(product: product, quantity: quantity ?? this.quantity);
  }
}

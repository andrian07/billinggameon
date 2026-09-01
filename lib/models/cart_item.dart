import 'cart_addon.dart';
import 'product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final String? note;
  final List<CartAddon> addons;

  const CartItem({
    required this.product,
    required this.quantity,
    this.note,
    this.addons = const [],
  });

  int get addonsTotal => addons.fold(0, (sum, addon) => sum + addon.lineTotal);

  int get lineTotal => product.price * quantity + addonsTotal;

  /// Preserves [note] and [addons] — use [withNote]/[withAddons] to change them.
  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      note: note,
      addons: addons,
    );
  }

  /// Replaces the note outright, so passing null clears it.
  CartItem withNote(String? note) {
    return CartItem(
      product: product,
      quantity: quantity,
      note: (note == null || note.isEmpty) ? null : note,
      addons: addons,
    );
  }

  /// Replaces the additional-item list outright.
  CartItem withAddons(List<CartAddon> addons) {
    return CartItem(
      product: product,
      quantity: quantity,
      note: note,
      addons: addons,
    );
  }
}

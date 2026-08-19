import 'product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final String? note;

  const CartItem({required this.product, required this.quantity, this.note});

  int get lineTotal => product.price * quantity;

  /// Preserves [note] — use [withNote] to change it.
  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      note: note,
    );
  }

  /// Replaces the note outright, so passing null clears it.
  CartItem withNote(String? note) {
    return CartItem(
      product: product,
      quantity: quantity,
      note: (note == null || note.isEmpty) ? null : note,
    );
  }
}

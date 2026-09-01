import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cart_addon.dart';
import '../../../models/cart_item.dart';
import '../../../models/product.dart';

/// Popup for managing the additional items (add-ons) attached to a cart
/// line — e.g. adding "Telur" to "Indomie". Each add-on is itself a product
/// with its own quantity, priced and stock-tracked independently of the
/// parent item's quantity. Pops with the updated [CartAddon] list, or null
/// if dismissed without saving.
class CartItemAddonDialog extends StatefulWidget {
  final CartItem item;
  final List<Product> products;

  const CartItemAddonDialog({
    super.key,
    required this.item,
    required this.products,
  });

  @override
  State<CartItemAddonDialog> createState() => _CartItemAddonDialogState();
}

class _CartItemAddonDialogState extends State<CartItemAddonDialog> {
  late final List<CartAddon> _addons = List.of(widget.item.addons);
  final _searchController = TextEditingController();
  String _search = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _pickableProducts {
    final query = _search.trim().toLowerCase();
    return widget.products.where((p) {
      if (p.id == widget.item.product.id) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          p.code.toLowerCase().contains(query);
    }).toList();
  }

  int _addonIndex(int productId) =>
      _addons.indexWhere((a) => a.product.id == productId);

  void _addOrIncrement(Product product) {
    setState(() {
      final index = _addonIndex(product.id);
      if (index == -1) {
        _addons.add(CartAddon(product: product, quantity: 1));
      } else {
        _addons[index] = _addons[index].copyWith(
          quantity: _addons[index].quantity + 1,
        );
      }
    });
  }

  void _incrementAt(int index) {
    setState(
      () => _addons[index] = _addons[index].copyWith(
        quantity: _addons[index].quantity + 1,
      ),
    );
  }

  void _decrementAt(int index) {
    setState(() {
      if (_addons[index].quantity <= 1) {
        _addons.removeAt(index);
      } else {
        _addons[index] = _addons[index].copyWith(
          quantity: _addons[index].quantity - 1,
        );
      }
    });
  }

  void _removeAt(int index) {
    setState(() => _addons.removeAt(index));
  }

  void _save() {
    Navigator.of(context).pop(_addons);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 16),
              if (_addons.isNotEmpty) ...[
                Text(
                  "Item Tambahan Terpilih",
                  style: AppText.bodySecondary.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSelectedAddons(),
                const SizedBox(height: 16),
              ],
              Text(
                "Pilih Produk",
                style: AppText.bodySecondary.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                style: AppText.body,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: "Cari nama atau kode produk...",
                  hintStyle: AppText.caption,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSizes.radiusMedium,
                    ),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSizes.radiusMedium,
                    ),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSizes.radiusMedium,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(child: _buildProductList()),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                        ),
                      ),
                      child: const Text("BATAL"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        elevation: 0,
                        textStyle: AppText.button,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                        ),
                      ),
                      child: const Text("SIMPAN"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.add_box_outlined,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text("Item tambahan untuk item ini", style: AppText.caption),
            ],
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedAddons() {
    return Column(
      children: [
        for (var i = 0; i < _addons.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _buildSelectedAddonRow(i),
        ],
      ],
    );
  }

  Widget _buildSelectedAddonRow(int index) {
    final addon = _addons[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.primary.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  addon.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  formatCurrency(addon.product.price),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          _qtyButton(Icons.remove_rounded, () => _decrementAt(index)),
          SizedBox(
            width: 26,
            child: Text(
              "${addon.quantity}",
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _qtyButton(Icons.add_rounded, () => _incrementAt(index)),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _removeAt(index),
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    final products = _pickableProducts;
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            "Tidak ada produk ditemukan",
            style: AppText.bodySecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: products.length,
      separatorBuilder: (_, _) =>
          const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final product = products[index];
        final selectedQty = () {
          final i = _addonIndex(product.id);
          return i == -1 ? 0 : _addons[i].quantity;
        }();

        return InkWell(
          onTap: () => _addOrIncrement(product),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body,
                      ),
                      Text(
                        formatCurrency(product.price),
                        style: AppText.caption.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedQty > 0) ...[
                  Text(
                    "x$selectedQty",
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 13, color: AppColors.textSecondary),
      ),
    );
  }
}

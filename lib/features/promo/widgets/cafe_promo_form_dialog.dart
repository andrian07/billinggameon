import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cafe_promo.dart';
import '../../../models/product.dart';
import '../../product/data/product_repository.dart';

class CafePromoFormResult {
  final String name;
  final int price;
  final List<int> productIds;

  const CafePromoFormResult({
    required this.name,
    required this.price,
    required this.productIds,
  });
}

/// Form tambah/edit promo cafe: nama, harga promo, dan pilih produk yang
/// dicakup (multi-select). Saat dipakai di POS, subtotal gabungan produk-produk
/// ini di keranjang di-reprice jadi [price].
class CafePromoFormDialog extends StatefulWidget {
  final CafePromo? promo;

  const CafePromoFormDialog({super.key, this.promo});

  bool get isEdit => promo != null;

  @override
  State<CafePromoFormDialog> createState() => _CafePromoFormDialogState();
}

class _CafePromoFormDialogState extends State<CafePromoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  final _searchController = TextEditingController();

  final _productRepository = ProductRepository();
  List<Product> _products = [];
  bool _loadingProducts = true;
  String? _productsError;

  final Set<int> _selectedIds = {};
  String _query = "";

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.promo?.name ?? "");
    _priceController = TextEditingController(
      text: widget.promo != null ? "${widget.promo!.price}" : "",
    );
    _selectedIds.addAll(widget.promo?.productIds ?? const []);
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });
    try {
      final products = await _productRepository.getProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productsError = e.toString();
        _loadingProducts = false;
      });
    }
  }

  List<Product> get _filtered {
    if (_query.trim().isEmpty) return _products;
    final q = _query.trim().toLowerCase();
    return _products
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih minimal 1 produk untuk promo ini")),
      );
      return;
    }
    Navigator.of(context).pop(
      CafePromoFormResult(
        name: _nameController.text.trim(),
        price: int.tryParse(_priceController.text.trim()) ?? 0,
        productIds: _selectedIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: screenSize.height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEdit ? "Edit Promo Cafe" : "Tambah Promo Cafe",
                  style: AppText.title.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  "Harga promo berlaku untuk gabungan produk yang dipilih",
                  style: AppText.caption,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Nama Promo",
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Wajib diisi" : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: "Harga Promo (Rp)",
                    isDense: true,
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? "");
                    if (n == null || n < 0) return "Masukkan angka yang valid";
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      "Produk Promo",
                      style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${_selectedIds.length} dipilih",
                          style: AppText.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Cari produk...",
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                Flexible(child: _buildProductList()),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          side: const BorderSide(color: AppColors.border),
                          foregroundColor: AppColors.textSecondary,
                        ),
                        child: const Text("BATAL"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: Text(widget.isEdit ? "SIMPAN" : "TAMBAH"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_loadingProducts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_productsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              _productsError!,
              style: AppText.caption.copyWith(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loadProducts,
              child: const Text("Coba Lagi"),
            ),
          ],
        ),
      );
    }

    final list = _filtered;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text("Produk tidak ditemukan", style: AppText.bodySecondary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: list.length,
        itemBuilder: (context, i) {
          final p = list[i];
          final selected = _selectedIds.contains(p.id);
          return CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
            value: selected,
            onChanged: (v) => setState(() {
              if (v == true) {
                _selectedIds.add(p.id);
              } else {
                _selectedIds.remove(p.id);
              }
            }),
            title: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body,
            ),
            subtitle: Text(formatCurrency(p.price), style: AppText.caption),
          );
        },
      ),
    );
  }
}

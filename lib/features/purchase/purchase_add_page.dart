import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/thousands_input_formatter.dart';
import '../../models/purchase.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import 'data/purchase_repository.dart';

enum _DiscountType { nominal, percent }

class PurchaseFormResult {
  final String? supplier;
  final String? supplierInvoice;
  final List<PurchaseItemInput> items;

  const PurchaseFormResult({
    this.supplier,
    this.supplierInvoice,
    required this.items,
  });
}

/// Full page (pushed via GoRouter) for recording a new stock purchase —
/// previously a modal dialog, moved to its own route so a long item list
/// has room to breathe instead of scrolling inside a fixed-size box.
class PurchaseAddPage extends StatefulWidget {
  const PurchaseAddPage({super.key});

  @override
  State<PurchaseAddPage> createState() => _PurchaseAddPageState();
}

class _PurchaseItemRow {
  PurchaseProduct? product;
  final TextEditingController productController = TextEditingController();
  final FocusNode productFocusNode = FocusNode();
  final TextEditingController qtyController = TextEditingController(
    text: "1",
  );
  final TextEditingController priceController = TextEditingController();

  int get qty => int.tryParse(qtyController.text.trim()) ?? 0;
  int get price => parseThousands(priceController.text) ?? (product?.cogs ?? 0);
  int get subTotal => qty * price;

  void dispose() {
    productController.dispose();
    productFocusNode.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class _PurchaseAddPageState extends State<PurchaseAddPage> {
  final _repository = PurchaseRepository();
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _supplierInvoiceController = TextEditingController();
  final _discountController = TextEditingController(text: "0");
  final List<_PurchaseItemRow> _rows = [_PurchaseItemRow()];
  final _today = DateTime.now();

  _DiscountType _discountType = _DiscountType.nominal;
  String? _itemsError;

  List<PurchaseProduct> _products = [];
  bool _loadingProducts = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _supplierInvoiceController.dispose();
    _discountController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _loadError = null;
    });

    try {
      final products = await _repository.getPurchaseProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } on PurchaseRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingProducts = false;
      });
    }
  }

  void _addRow() => setState(() => _rows.add(_PurchaseItemRow()));

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  int get _subtotal => _rows.fold(0, (sum, row) => sum + row.subTotal);

  int get _discountAmount {
    final subtotal = _subtotal;
    if (subtotal <= 0) return 0;

    final raw = parseThousands(_discountController.text) ?? 0;
    if (_discountType == _DiscountType.percent) {
      final pct = raw.clamp(0, 100);
      return ((subtotal * pct) / 100).round().clamp(0, subtotal);
    }
    return raw.clamp(0, subtotal);
  }

  int get _total => _subtotal - _discountAmount;

  void _submit() {
    final formValid = _formKey.currentState!.validate();

    final validRows = <_PurchaseItemRow>[];
    for (final row in _rows) {
      if (row.product == null) continue;
      if (row.qty <= 0) continue;
      validRows.add(row);
    }

    setState(() {
      _itemsError = validRows.isEmpty
          ? "Tambahkan minimal 1 item pembelian"
          : null;
    });

    if (!formValid || _itemsError != null) return;

    Navigator.of(context).pop(
      PurchaseFormResult(
        supplier: _supplierController.text.trim().isEmpty
            ? null
            : _supplierController.text.trim(),
        supplierInvoice: _supplierInvoiceController.text.trim().isEmpty
            ? null
            : _supplierInvoiceController.text.trim(),
        items: _buildDiscountedItems(validRows),
      ),
    );
  }

  /// Spreads [_discountAmount] proportionally across each row's subtotal so
  /// the total actually recorded by purchase_add (sum of price * qty)
  /// matches the "Total" shown in the footer — the endpoint itself has no
  /// discount parameter.
  List<PurchaseItemInput> _buildDiscountedItems(List<_PurchaseItemRow> rows) {
    final subtotal = _subtotal;
    final discount = _discountAmount;
    if (discount <= 0 || subtotal <= 0) {
      return [
        for (final row in rows)
          PurchaseItemInput(
            productId: row.product!.id,
            qty: row.qty,
            price: row.price,
          ),
      ];
    }

    var remainingDiscount = discount;
    final items = <PurchaseItemInput>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final isLast = i == rows.length - 1;
      final rowDiscount = isLast
          ? remainingDiscount.clamp(0, row.subTotal)
          : (((row.subTotal * discount) / subtotal).round()).clamp(
              0,
              row.subTotal,
            );
      remainingDiscount -= rowDiscount;

      final adjustedSubtotal = row.subTotal - rowDiscount;
      final adjustedPrice = row.qty == 0
          ? row.price
          : (adjustedSubtotal / row.qty).round();
      items.add(
        PurchaseItemInput(
          productId: row.product!.id,
          qty: row.qty,
          price: adjustedPrice,
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Tambah Pembelian",
      subtitle: "Catat transaksi pembelian stok baru",
      showSearch: false,
      activeMenuKey: "pembelian",
      onMenuSelect: (key) => navigateToMenu(context, key),
      onRefresh: _loadProducts,
      child: AppCard(
        padding: EdgeInsets.zero,
        child: _loadingProducts
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? _buildLoadError()
            : _buildForm(),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 30,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: AppText.bodySecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Coba Lagi"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: _buildToolbar(),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderFields(),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.divider, height: 1),
                      const SizedBox(height: 24),
                      _buildItemsSection(),
                      const SizedBox(height: 24),
                      _buildFooterSummary(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: _buildActions(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Toolbar ──────────────────────────────────────────────────────────

  Widget _buildToolbar() {
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
            Icons.shopping_cart_checkout_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tambah Pembelian",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                "Catat transaksi pembelian stok baru",
                style: AppText.caption,
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text("Kembali"),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
          ),
        ),
      ],
    );
  }

  // ── Header: invoice / date / supplier ───────────────────────────────

  Widget _buildHeaderFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _infoField(
                label: "No. Invoice",
                icon: Icons.receipt_long_outlined,
                value: "Dibuat otomatis",
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _infoField(
                label: "Tanggal Transaksi",
                icon: Icons.calendar_today_outlined,
                value: formatFullDate(_today),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label("Supplier (opsional)"),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _supplierController,
                    style: AppText.body,
                    decoration: _inputDecoration(
                      hint: "Mis. Toko Sembako Jaya",
                      prefixIcon: Icons.storefront_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label("No. Invoice Supplier (opsional)"),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _supplierInvoiceController,
                    style: AppText.body,
                    decoration: _inputDecoration(
                      hint: "Mis. No. nota dari supplier",
                      prefixIcon: Icons.description_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoField({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textHint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Content: purchase items ─────────────────────────────────────────

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("Item Pembelian"),
        const SizedBox(height: 10),
        _buildItemsHeaderRow(),
        const SizedBox(height: 6),
        for (var i = 0; i < _rows.length; i++) ...[
          _buildItemRow(i),
          const SizedBox(height: 10),
        ],
        if (_itemsError != null) ...[
          Text(
            _itemsError!,
            style: AppText.caption.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text("Tambah Item"),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: .4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsHeaderRow() {
    TextStyle style = AppText.caption.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: .4,
      color: AppColors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text("PRODUK", style: style)),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text("QTY", style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 150,
            child: Text("HARGA BELI", style: style, textAlign: TextAlign.end),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Text("SUBTOTAL", style: style, textAlign: TextAlign.end),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final row = _rows[index];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 5, child: _buildProductSearchField(row)),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextFormField(
              controller: row.qtyController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppText.body,
              decoration: _inputDecoration(hint: "Qty"),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 150,
            child: TextFormField(
              controller: row.priceController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              inputFormatters: const [ThousandsInputFormatter()],
              style: AppText.body,
              decoration: _inputDecoration(hint: "Harga"),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Text(
              formatCurrency(row.subTotal),
              textAlign: TextAlign.end,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 32,
            child: _rows.length > 1
                ? InkWell(
                    onTap: () => _removeRow(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.danger.withValues(alpha: .8),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// Select2-style searchable product picker, filtering by code or name
  /// against the products supplied by Purchase/list_product_purchase.
  Widget _buildProductSearchField(_PurchaseItemRow row) {
    return Autocomplete<PurchaseProduct>(
      textEditingController: row.productController,
      focusNode: row.productFocusNode,
      displayStringForOption: (p) => p.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return _products;
        return _products.where(
          (p) =>
              p.name.toLowerCase().contains(query) ||
              p.code.toLowerCase().contains(query),
        );
      },
      onSelected: (product) {
        row.product = product;
        row.priceController.text = formatThousands(product.cogs);
        setState(() {});
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          style: AppText.body,
          decoration: _inputDecoration(
            hint: "Cari kode / nama produk",
            prefixIcon: Icons.search_rounded,
          ),
          validator: (_) =>
              row.product == null && controller.text.trim().isNotEmpty
              ? "Pilih produk dari daftar"
              : null,
          onChanged: (_) {
            if (row.product != null) setState(() => row.product = null);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _buildOptionsCard(options: options, onSelected: onSelected);
      },
    );
  }

  Widget _buildOptionsCard({
    required Iterable<PurchaseProduct> options,
    required void Function(PurchaseProduct) onSelected,
  }) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: AppColors.card,
        elevation: 8,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 260),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: options.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Text("Produk tidak ditemukan", style: AppText.caption),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final product = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(product),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: AppText.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${product.code} · Stok ${product.stock}"
                                    "${product.categoryName != null ? ' · ${product.categoryName}' : ''}",
                                    style: AppText.caption,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatCurrency(product.cogs),
                              style: AppText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  // ── Footer: subtotal / diskon / total ───────────────────────────────

  Widget _buildFooterSummary() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow("Subtotal", formatCurrency(_subtotal)),
            const SizedBox(height: 10),
            _buildDiscountRow(),
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            _summaryRow("Total", formatCurrency(_total), emphasize: true),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: emphasize
              ? AppText.body.copyWith(fontWeight: FontWeight.w700)
              : AppText.bodySecondary,
        ),
        Text(
          value,
          style: emphasize
              ? AppText.title.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                )
              : AppText.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDiscountRow() {
    return Row(
      children: [
        Text("Diskon", style: AppText.bodySecondary),
        const Spacer(),
        _buildDiscountTypeToggle(),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          height: 36,
          child: TextFormField(
            controller: _discountController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            style: AppText.body,
            inputFormatters: _discountType == _DiscountType.percent
                ? [FilteringTextInputFormatter.digitsOnly]
                : const [ThousandsInputFormatter()],
            decoration: _inputDecoration(hint: "0").copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              suffixText: _discountType == _DiscountType.percent ? "%" : null,
              suffixStyle: AppText.caption,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountTypeToggle() {
    Widget option(String label, _DiscountType type) {
      final active = _discountType == type;
      return InkWell(
        onTap: () => setState(() {
          if (_discountType != type) _discountController.text = "0";
          _discountType = type;
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        option("Rp", _DiscountType.nominal),
        const SizedBox(width: 4),
        option("%", _DiscountType.percent),
      ],
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
            child: const Text("BATAL"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text("SIMPAN PEMBELIAN"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              elevation: 0,
              textStyle: AppText.button,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _inputDecoration({String? hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary)
          : null,
      filled: true,
      fillColor: AppColors.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}

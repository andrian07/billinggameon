import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/thousands_input_formatter.dart';
import '../../../models/product.dart';
import '../../../models/product_category.dart';
import '../../../models/unit.dart';
import '../data/product_repository.dart';

class ProductFormResult {
  final String name;
  final int categoryId;
  final int unitId;
  final int price;
  final int cogs;
  final int stock;
  final bool reduceStock;
  final ProductImageInput? image;

  const ProductFormResult({
    required this.name,
    required this.categoryId,
    required this.unitId,
    required this.price,
    required this.cogs,
    required this.stock,
    required this.reduceStock,
    this.image,
  });
}

class ProductFormDialog extends StatefulWidget {
  final Product? product;
  final List<ProductCategory> categories;
  final List<Unit> units;

  const ProductFormDialog({
    super.key,
    this.product,
    required this.categories,
    required this.units,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.product?.name ?? "",
  );
  late final _priceController = TextEditingController(
    text: widget.product != null
        ? formatThousands(widget.product!.price)
        : "",
  );
  late final _cogsController = TextEditingController(
    text: widget.product != null ? formatThousands(widget.product!.cogs) : "",
  );
  late final _stockController = TextEditingController(
    text: widget.product != null ? "${widget.product!.stock}" : "0",
  );
  late int? _categoryId = widget.product?.categoryId;
  late int? _unitId = widget.product?.unitId;
  late bool _reduceStock = widget.product?.reduceStock ?? true;

  PlatformFile? _pickedImage;

  bool get _isEdit => widget.product != null;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _cogsController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _pickedImage = result.files.first);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null || _unitId == null) return;

    final image = _pickedImage;

    Navigator.of(context).pop(
      ProductFormResult(
        name: _nameController.text.trim(),
        categoryId: _categoryId!,
        unitId: _unitId!,
        price: parseThousands(_priceController.text) ?? 0,
        cogs: parseThousands(_cogsController.text) ?? 0,
        stock: int.tryParse(_stockController.text.trim()) ?? 0,
        reduceStock: _reduceStock,
        image: image != null && image.bytes != null
            ? ProductImageInput(filename: image.name, bytes: image.bytes!)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 22),

                _label("Gambar Produk"),
                const SizedBox(height: 8),
                _buildImagePicker(),

                const SizedBox(height: 20),
                _label("Nama Produk"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: AppText.body,
                  decoration: _inputDecoration(
                    hint: "Masukkan nama produk",
                    prefixIcon: Icons.inventory_2_outlined,
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                      ? "Nama produk wajib diisi"
                      : null,
                ),

                const SizedBox(height: 20),
                _label("Kategori"),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: _categoryId,
                  dropdownColor: AppColors.card,
                  style: AppText.body,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                  decoration: _inputDecoration(
                    hint: "Pilih kategori",
                    prefixIcon: Icons.category_outlined,
                  ),
                  items: [
                    for (final category in widget.categories)
                      DropdownMenuItem<int?>(
                        value: category.id,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? "Kategori wajib dipilih" : null,
                ),

                const SizedBox(height: 20),
                _label("Unit"),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: _unitId,
                  dropdownColor: AppColors.card,
                  style: AppText.body,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                  decoration: _inputDecoration(
                    hint: "Pilih unit",
                    prefixIcon: Icons.straighten_outlined,
                  ),
                  items: [
                    for (final unit in widget.units)
                      DropdownMenuItem<int?>(
                        value: unit.id,
                        child: Text(
                          unit.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _unitId = value),
                  validator: (value) =>
                      value == null ? "Unit wajib dipilih" : null,
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label("Harga Jual"),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              ThousandsInputFormatter(),
                            ],
                            style: AppText.body,
                            decoration: _inputDecoration(
                              hint: "0",
                              prefixIcon: Icons.payments_outlined,
                            ),
                            validator: (value) {
                              final parsed = parseThousands(value ?? "");
                              if (parsed == null || parsed <= 0) {
                                return "Harga tidak valid";
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label("Modal (COGS)"),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _cogsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [
                              ThousandsInputFormatter(),
                            ],
                            style: AppText.body,
                            decoration: _inputDecoration(
                              hint: "0",
                              prefixIcon: Icons.receipt_long_outlined,
                            ),
                            validator: (value) {
                              final parsed = parseThousands(value ?? "");
                              if (parsed == null || parsed < 0) {
                                return "Modal tidak valid";
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _label("Stok"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _stockController,
                  readOnly: true,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  style: AppText.body.copyWith(color: AppColors.textSecondary),
                  decoration: _inputDecoration(
                    hint: "0",
                    prefixIcon: Icons.numbers_rounded,
                  ).copyWith(fillColor: AppColors.background),
                ),
                const SizedBox(height: 6),
                Text(
                  "Stok bertambah otomatis lewat menu Pembelian dan tidak bisa diubah manual di sini",
                  style: AppText.caption,
                ),

                const SizedBox(height: 16),
                _buildReduceStockToggle(),

                const SizedBox(height: 28),
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
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: Icon(
                          _isEdit ? Icons.save_outlined : Icons.add_rounded,
                          size: 20,
                        ),
                        label: Text(_isEdit ? "SIMPAN" : "TAMBAH PRODUK"),
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

  Widget _buildImagePicker() {
    final existingUrl = widget.product?.imageUrl;
    final hasExisting =
        existingUrl != null &&
        existingUrl.isNotEmpty &&
        !existingUrl.endsWith("default.jpg");

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              child: SizedBox(
                width: 44,
                height: 44,
                child: _pickedImage?.bytes != null
                    ? Image.memory(_pickedImage!.bytes!, fit: BoxFit.cover)
                    : hasExisting
                    ? Image.network(
                        existingUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _pickedImage?.name ??
                    (hasExisting ? "Gambar saat ini" : "Belum ada gambar"),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySecondary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "PILIH FILE",
              style: AppText.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.textHint.withValues(alpha: .12),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: AppColors.textHint,
      ),
    );
  }

  Widget _buildReduceStockToggle() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Produk Memiliki Stok",
                style: AppText.body.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                "Stok berkurang setiap kali produk ini terjual",
                style: AppText.caption,
              ),
            ],
          ),
        ),
        Switch(
          value: _reduceStock,
          activeThumbColor: AppColors.primary,
          onChanged: (value) => setState(() => _reduceStock = value),
        ),
      ],
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
            Icons.inventory_2_outlined,
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
                _isEdit ? "Edit Produk" : "Tambah Produk",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _isEdit ? "Perbarui data produk" : "Buat produk baru",
                style: AppText.caption,
              ),
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
      fillColor: AppColors.background,
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

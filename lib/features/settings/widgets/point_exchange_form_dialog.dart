import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/point_exchange.dart';
import '../data/point_exchange_repository.dart';

class PointExchangeFormResult {
  final String name;
  final int point;
  final String description;
  final PointExchangeImageInput? image;

  const PointExchangeFormResult({
    required this.name,
    required this.point,
    required this.description,
    this.image,
  });
}

class PointExchangeFormDialog extends StatefulWidget {
  final PointExchange? item;

  const PointExchangeFormDialog({super.key, this.item});

  @override
  State<PointExchangeFormDialog> createState() =>
      _PointExchangeFormDialogState();
}

class _PointExchangeFormDialogState extends State<PointExchangeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.item?.name ?? "",
  );
  late final _pointController = TextEditingController(
    text: widget.item != null ? "${widget.item!.point}" : "",
  );
  late final _descController = TextEditingController(
    text: widget.item?.description ?? "",
  );

  PlatformFile? _pickedImage;

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _nameController.dispose();
    _pointController.dispose();
    _descController.dispose();
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

    final image = _pickedImage;

    Navigator.of(context).pop(
      PointExchangeFormResult(
        name: _nameController.text.trim(),
        point: int.tryParse(_pointController.text.trim()) ?? 0,
        description: _descController.text.trim(),
        image: image != null && image.bytes != null
            ? PointExchangeImageInput(filename: image.name, bytes: image.bytes!)
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

                _label("Gambar Hadiah"),
                const SizedBox(height: 8),
                _buildImagePicker(),

                const SizedBox(height: 20),
                _label("Nama Hadiah"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: AppText.body,
                  decoration: _inputDecoration(
                    hint: "Masukkan nama hadiah",
                    prefixIcon: Icons.card_giftcard_rounded,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? "Nama hadiah wajib diisi"
                      : null,
                ),

                const SizedBox(height: 20),
                _label("Point"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pointController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppText.body,
                  decoration: _inputDecoration(
                    hint: "0",
                    prefixIcon: Icons.toll_outlined,
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? "");
                    if (parsed == null || parsed <= 0) {
                      return "Point tidak valid";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),
                _label("Deskripsi"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: AppText.body,
                  decoration: _inputDecoration(hint: "Deskripsi hadiah"),
                ),

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
                        label: Text(_isEdit ? "SIMPAN" : "TAMBAH HADIAH"),
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
    final existingUrl = widget.item?.imageUrl ?? "";
    final hasExisting = existingUrl.isNotEmpty;

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
                    (hasExisting
                        ? "Gambar saat ini"
                        : "Belum ada gambar (pakai default)"),
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
            Icons.card_giftcard_rounded,
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
                _isEdit ? "Edit Tukar Point" : "Tambah Tukar Point",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _isEdit ? "Perbarui data hadiah" : "Buat hadiah baru",
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

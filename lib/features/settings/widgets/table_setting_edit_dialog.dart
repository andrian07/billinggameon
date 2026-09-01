import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/table_category.dart';
import '../../../models/table_setting.dart';
import '../data/table_category_repository.dart';

class TableSettingEditResult {
  final String number;
  final int relay;
  final int point;
  final int? categoryId;

  const TableSettingEditResult({
    required this.number,
    required this.relay,
    required this.point,
    this.categoryId,
  });
}

class TableSettingEditDialog extends StatefulWidget {
  final TableSetting table;

  const TableSettingEditDialog({super.key, required this.table});

  @override
  State<TableSettingEditDialog> createState() => _TableSettingEditDialogState();
}

class _TableSettingEditDialogState extends State<TableSettingEditDialog> {
  final _categoryRepository = TableCategoryRepository();

  final _formKey = GlobalKey<FormState>();
  late final _numberController = TextEditingController(
    text: widget.table.number,
  );
  late final _relayController = TextEditingController(
    text: "${widget.table.relay}",
  );
  late final _pointController = TextEditingController(
    text: "${widget.table.point}",
  );

  bool _loadingCategories = true;
  String? _categoryError;
  List<TableCategory> _categories = [];
  late int? _selectedCategoryId = widget.table.categoryId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });

    try {
      final result = await _categoryRepository.getTableCategories(
        page: 1,
        perPage: 200,
      );
      if (!mounted) return;
      setState(() {
        _categories = result.items.where((c) => c.active).toList();
        _loadingCategories = false;
      });
    } on TableCategoryRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _categoryError = e.message;
        _loadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _relayController.dispose();
    _pointController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      TableSettingEditResult(
        number: _numberController.text.trim(),
        relay: int.tryParse(_relayController.text.trim()) ?? 0,
        point: int.tryParse(_pointController.text.trim()) ?? 0,
        categoryId: _selectedCategoryId,
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
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 22),

              _label("Nomor Meja"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _numberController,
                autofocus: true,
                style: AppText.body,
                decoration: _inputDecoration(
                  hint: "Mis. 01 / VVIP",
                  prefixIcon: Icons.table_bar_rounded,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? "Nomor meja wajib diisi"
                    : null,
              ),

              const SizedBox(height: 16),
              _label("Relay"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _relayController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppText.body,
                decoration: _inputDecoration(
                  hint: "0",
                  prefixIcon: Icons.settings_input_component_rounded,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Relay wajib diisi";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),
              _label("Point / Jam"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pointController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppText.body,
                decoration: _inputDecoration(
                  hint: "0",
                  prefixIcon: Icons.grid_on_rounded,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Point wajib diisi";
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),

              const SizedBox(height: 16),
              _label("Kategori Meja"),
              const SizedBox(height: 8),
              _buildCategoryField(),

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
                      icon: const Icon(Icons.save_outlined, size: 20),
                      label: const Text("SIMPAN"),
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
            Icons.settings_input_component_rounded,
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
                "Edit Setting Meja",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text("Meja ${widget.table.number}", style: AppText.caption),
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

  Widget _buildCategoryField() {
    if (_loadingCategories) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text("Memuat kategori...", style: AppText.caption),
          ],
        ),
      );
    }

    if (_categoryError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: AppColors.danger.withValues(alpha: .3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: AppColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _categoryError!,
                style: AppText.caption.copyWith(color: AppColors.danger),
              ),
            ),
            TextButton(
              onPressed: _loadCategories,
              child: const Text("Coba Lagi"),
            ),
          ],
        ),
      );
    }

    // Keep the table's current category selectable even if it's since been
    // deactivated/removed from the master list, so saving doesn't silently
    // drop it.
    final options = {for (final c in _categories) c.id: c.name};
    if (_selectedCategoryId != null && !options.containsKey(_selectedCategoryId)) {
      options[_selectedCategoryId!] = widget.table.categoryName ?? "Kategori #$_selectedCategoryId";
    }

    return DropdownButtonFormField<int?>(
      initialValue: _selectedCategoryId,
      dropdownColor: AppColors.card,
      style: AppText.body,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.textSecondary,
      ),
      decoration: _inputDecoration(
        hint: "Tanpa kategori",
        prefixIcon: Icons.category_outlined,
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text("Tanpa Kategori"),
        ),
        for (final entry in options.entries)
          DropdownMenuItem<int?>(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => _selectedCategoryId = value),
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

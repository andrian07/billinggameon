import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/thousands_input_formatter.dart';
import '../../../models/promo.dart';

class PromoFormResult {
  final String name;
  final PromoType type;
  final int value;
  final int? hourGained;

  const PromoFormResult({
    required this.name,
    required this.type,
    required this.value,
    this.hourGained,
  });
}

class PromoFormDialog extends StatefulWidget {
  final Promo? promo;

  const PromoFormDialog({super.key, this.promo});

  @override
  State<PromoFormDialog> createState() => _PromoFormDialogState();
}

class _PromoFormDialogState extends State<PromoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.promo?.name ?? "",
  );
  late final _valueController = TextEditingController(
    text: widget.promo != null ? formatThousands(widget.promo!.value) : "",
  );
  late final _hourController = TextEditingController(
    text: widget.promo?.hourGained != null
        ? "${widget.promo!.hourGained}"
        : "",
  );
  late PromoType _type = widget.promo?.type ?? PromoType.percentage;

  bool get _isEdit => widget.promo != null;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _hourController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      PromoFormResult(
        name: _nameController.text.trim(),
        type: _type,
        value: parseThousands(_valueController.text) ?? 0,
        hourGained: _type == PromoType.fixed
            ? int.tryParse(_hourController.text.trim())
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
        width: 420,
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

                _label("Nama Promo"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: AppText.body,
                  decoration: _inputDecoration(
                    hint: "Masukkan nama promo",
                    prefixIcon: Icons.local_offer_outlined,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? "Nama promo wajib diisi"
                      : null,
                ),

                const SizedBox(height: 20),
                _label("Tipe Promo"),
                const SizedBox(height: 8),
                _buildTypeSelector(),

                const SizedBox(height: 20),
                _label(
                  _type == PromoType.percentage
                      ? "Nilai Diskon (%)"
                      : "Nilai Diskon (Rp)",
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  style: AppText.body,
                  decoration: _inputDecoration(
                    hint: _type == PromoType.percentage ? "0" : "0",
                    prefixIcon: Icons.payments_outlined,
                    suffixText: _type == PromoType.percentage ? "%" : null,
                  ),
                  validator: (value) {
                    final parsed = parseThousands(value ?? "");
                    if (parsed == null || parsed < 0) {
                      return "Masukkan angka yang valid";
                    }
                    if (_type == PromoType.percentage && parsed > 100) {
                      return "Diskon persen maksimal 100";
                    }
                    return null;
                  },
                ),

                if (_type == PromoType.fixed) ...[
                  const SizedBox(height: 20),
                  _label("Jam yang Didapat"),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _hourController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: AppText.body,
                    decoration: _inputDecoration(
                      hint: "0",
                      prefixIcon: Icons.timer_outlined,
                      suffixText: "jam",
                    ),
                    validator: (value) {
                      final parsed = int.tryParse((value ?? "").trim());
                      if (parsed == null || parsed <= 0) {
                        return "Masukkan jumlah jam yang valid";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Durasi timer otomatis terisi & terkunci sebesar ini "
                    "saat promo ini dipilih di open billing.",
                    style: AppText.caption,
                  ),
                ],

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
                          _isEdit
                              ? Icons.save_outlined
                              : Icons.local_offer_outlined,
                          size: 20,
                        ),
                        label: Text(_isEdit ? "SIMPAN" : "TAMBAH PROMO"),
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

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(child: _typeOption(PromoType.percentage)),
        const SizedBox(width: 10),
        Expanded(child: _typeOption(PromoType.fixed)),
      ],
    );
  }

  Widget _typeOption(PromoType type) {
    final active = _type == type;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: .15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          type.label,
          style: AppText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: active ? AppColors.primary : AppColors.textSecondary,
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
            Icons.local_offer_outlined,
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
                _isEdit ? "Edit Promo" : "Tambah Promo",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _isEdit ? "Perbarui data promo" : "Buat promo baru",
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

  InputDecoration _inputDecoration({
    String? hint,
    IconData? prefixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary)
          : null,
      suffixText: suffixText,
      suffixStyle: AppText.body.copyWith(color: AppColors.textSecondary),
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

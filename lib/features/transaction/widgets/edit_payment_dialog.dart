import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/payment_method.dart';
import '../../payment/data/payment_method_repository.dart';

/// Popup for changing an already-completed transaction's payment method —
/// shared by the billing and cafe transaction lists. "Potong Saldo" is
/// excluded from the picker (and callers should keep this dialog off the
/// action row entirely for a transaction whose CURRENT method is Potong
/// Saldo) since the backend rejects edits touching that method on either
/// side — no logic exists to correct a customer's saldo after the fact.
class EditPaymentDialog extends StatefulWidget {
  final String invoiceNumber;
  final int currentPaymentId;
  final String currentPaymentName;

  const EditPaymentDialog({
    super.key,
    required this.invoiceNumber,
    required this.currentPaymentId,
    required this.currentPaymentName,
  });

  @override
  State<EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<EditPaymentDialog> {
  static const _excludedName = "Potong Saldo";

  final _repository = PaymentMethodRepository();

  bool _loading = true;
  String? _error;
  List<PaymentMethod> _methods = [];
  PaymentMethod? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final methods = await _repository.getPaymentMethods();
      if (!mounted) return;
      final filtered = methods.where((m) => m.name != _excludedName).toList();
      setState(() {
        _methods = filtered;
        _selected = filtered.firstWhere(
          (m) => m.id == widget.currentPaymentId,
          orElse: () => filtered.isNotEmpty
              ? filtered.first
              : const PaymentMethod(id: 0, name: "-"),
        );
        _loading = false;
      });
    } on PaymentMethodRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _save() {
    if (_selected == null || _selected!.id == 0) return;
    Navigator.of(context).pop(_selected);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 20),
            _buildBody(),
            const SizedBox(height: 24),
            _buildActions(),
          ],
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
            Icons.sync_alt_rounded,
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
                "Ubah Metode Pembayaran",
                style: AppText.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(widget.invoiceNumber, style: AppText.caption),
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

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error!,
            style: AppText.bodySecondary.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text("Coba Lagi")),
        ],
      );
    }

    if (_methods.isEmpty) {
      return Text(
        "Tidak ada metode pembayaran lain yang tersedia.",
        style: AppText.bodySecondary,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Saat ini", style: AppText.bodySecondary),
            Text(
              widget.currentPaymentName,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "Metode Baru",
          style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PaymentMethod>(
          initialValue: _selected,
          dropdownColor: AppColors.card,
          style: AppText.body,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
          items: [
            for (final method in _methods)
              DropdownMenuItem(value: method, child: Text(method.name)),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selected = value);
          },
        ),
      ],
    );
  }

  Widget _buildActions() {
    final canSave =
        !_loading && _error == null && _selected != null && _selected!.id != 0;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
            child: const Text("BATAL"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: canSave ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.textHint,
              minimumSize: const Size(0, 46),
              elevation: 0,
              textStyle: AppText.button,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
            child: const Text("SIMPAN"),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/keep_transaction.dart';
import '../data/cafe_repository.dart';

class KeepTransactionNameResult {
  final String name;

  /// Set when [name] exactly matches an already-held transaction — the
  /// caller should merge the cart into that transaction (via its id)
  /// instead of parking a brand new one.
  final int? matchedKeepTransactionId;

  const KeepTransactionNameResult({
    required this.name,
    this.matchedKeepTransactionId,
  });
}

/// Prompts for an optional label before parking a new order via
/// Cafe/keep_transaction (e.g. "Meja VIP - Budi"), so it's easier to spot
/// in the "Pesanan Tertunda" list later. Only asked when creating a new
/// keep transaction — the name is ignored once one already exists.
///
/// Also suggests names already used by other held transactions. Picking (or
/// simply typing) a name that matches one exactly is treated as "add this
/// cart to that existing order" rather than parking a separate duplicate.
class KeepTransactionNameDialog extends StatefulWidget {
  const KeepTransactionNameDialog({super.key});

  @override
  State<KeepTransactionNameDialog> createState() =>
      _KeepTransactionNameDialogState();
}

class _KeepTransactionNameDialogState extends State<KeepTransactionNameDialog> {
  final _repository = CafeRepository();

  // Owned by Autocomplete's internal state, not this widget — captured here
  // just so _submit() can read the current text (typed or picked).
  TextEditingController? _fieldController;

  List<KeepTransaction> _existingTransactions = [];
  KeepTransaction? _matched;

  List<String> get _existingNames => _existingTransactions
      .map((t) => t.name)
      .whereType<String>()
      .toSet()
      .toList();

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final transactions = await _repository.getKeepTransactions();
      if (!mounted) return;
      setState(() => _existingTransactions = transactions);
    } on CafeRepositoryException {
      // Suggestions are a nice-to-have — typing a fresh name still works.
    }
  }

  KeepTransaction? _findMatch(String name) {
    if (name.isEmpty) return null;
    for (final transaction in _existingTransactions) {
      if (transaction.name?.toLowerCase() == name.toLowerCase()) {
        return transaction;
      }
    }
    return null;
  }

  void _onNameChanged(String text) {
    final match = _findMatch(text.trim());
    if (match?.id != _matched?.id) setState(() => _matched = match);
  }

  void _submit() {
    final name = _fieldController?.text.trim() ?? "";
    Navigator.of(context).pop(
      KeepTransactionNameResult(
        name: name,
        matchedKeepTransactionId: _findMatch(name)?.id,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 22),

            _label("Nama Pesanan (opsional)"),
            const SizedBox(height: 8),
            _buildNameField(),
            if (_matched != null) ...[
              const SizedBox(height: 8),
              _buildMatchHint(_matched!),
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
                    icon: const Icon(
                      Icons.pause_circle_outline_rounded,
                      size: 20,
                    ),
                    label: const Text("SIMPAN"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
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
    );
  }

  Widget _buildNameField() {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return _existingNames;
        final query = textEditingValue.text.toLowerCase();
        return _existingNames.where(
          (name) => name.toLowerCase().contains(query),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _fieldController = controller;

        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          style: AppText.body,
          decoration: _inputDecoration(
            hint: "Mis. Meja VIP - Budi",
            prefixIcon: Icons.badge_outlined,
          ),
          onChanged: _onNameChanged,
          onSubmitted: (_) => _submit(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: AppColors.card,
            elevation: 8,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            child: Container(
              width: 352,
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final name = options.elementAt(index);
                  return InkWell(
                    onTap: () {
                      onSelected(name);
                      _onNameChanged(name);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(name, style: AppText.body),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchHint(KeepTransaction match) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.info.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.info,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Item akan ditambahkan ke pesanan \"${match.name}\" yang sudah ada (${match.invoiceNumber})",
              style: AppText.caption.copyWith(color: AppColors.info),
            ),
          ),
        ],
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
            color: AppColors.warning.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.pause_circle_outline_rounded,
            color: AppColors.warning,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tahan Pesanan",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                "Beri nama agar mudah ditemukan nanti",
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
    );
  }
}

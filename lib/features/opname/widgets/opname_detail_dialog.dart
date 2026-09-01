import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/stock_opname.dart';
import '../data/opname_repository.dart';

class OpnameDetailDialog extends StatefulWidget {
  final int opnameId;

  const OpnameDetailDialog({super.key, required this.opnameId});

  @override
  State<OpnameDetailDialog> createState() => _OpnameDetailDialogState();
}

class _OpnameDetailDialogState extends State<OpnameDetailDialog> {
  final _repository = OpnameRepository();

  bool _loading = true;
  String? _error;
  StockOpnameDetail? _detail;

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
      final detail = await _repository.getOpnameDetail(widget.opnameId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on OpnameRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
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
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            border: Border.all(color: AppColors.border),
          ),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: AppText.bodySecondary),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text("Coba Lagi")),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(detail),
        const SizedBox(height: 16),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(flex: 3, child: _headerText("Produk")),
            Expanded(child: _headerText("Sistem", alignEnd: true)),
            Expanded(child: _headerText("Fisik", alignEnd: true)),
            Expanded(child: _headerText("Selisih", alignEnd: true)),
          ],
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: detail.items.length,
            separatorBuilder: (_, _) =>
                const Divider(color: AppColors.divider, height: 1),
            itemBuilder: (context, index) => _buildItemRow(detail.items[index]),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
            child: const Text("TUTUP"),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(StockOpnameDetail detail) {
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
            Icons.fact_check_outlined,
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
                detail.invoiceNumber,
                style: AppText.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "${formatDate(detail.date)} · ${detail.createdBy}"
                "${detail.note != null ? ' · ${detail.note}' : ''}",
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

  Widget _headerText(String text, {bool alignEnd = false}) {
    return Text(
      text,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: AppText.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildItemRow(StockOpnameItem item) {
    final diff = item.difference;
    final diffColor = diff == 0
        ? AppColors.textHint
        : (diff > 0 ? AppColors.success : AppColors.danger);
    final diffText = diff == 0 ? "0" : (diff > 0 ? "+$diff" : "$diff");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              "${item.systemStock}",
              textAlign: TextAlign.end,
              style: AppText.caption,
            ),
          ),
          Expanded(
            child: Text(
              "${item.physicalStock}",
              textAlign: TextAlign.end,
              style: AppText.caption,
            ),
          ),
          Expanded(
            child: Text(
              diffText,
              textAlign: TextAlign.end,
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: diffColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/pool_table.dart';
import '../../../models/transaction.dart';
import '../data/transaction_repository.dart';

class TransactionDetailDialog extends StatefulWidget {
  final int transactionId;

  const TransactionDetailDialog({super.key, required this.transactionId});

  @override
  State<TransactionDetailDialog> createState() =>
      _TransactionDetailDialogState();
}

class _TransactionDetailDialogState extends State<TransactionDetailDialog> {
  final _repository = TransactionRepository();

  bool _loading = true;
  String? _error;
  TransactionDetail? _detail;

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
      final detail = await _repository.getTransactionDetail(
        widget.transactionId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on TransactionRepositoryException catch (e) {
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
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 20),
              _buildBody(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                    ),
                  ),
                  child: const Text("TUTUP"),
                ),
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
            color: AppColors.info.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: AppColors.info,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Detail Transaksi",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _detail?.invoiceNumber ?? "Memuat...",
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

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildInlineError(_error!, onRetry: _load);
    }

    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();

    final isCompleted = detail.status == TransactionStatus.completed;
    final statusColor = isCompleted ? AppColors.success : AppColors.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              isCompleted ? "Selesai" : "Dibatalkan",
              style: AppText.caption.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        _label("Detail Sesi"),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _kv(Icons.table_bar_rounded, "Meja", detail.tableName),
              const SizedBox(height: 10),
              _kv(
                Icons.sports_esports_rounded,
                "Mode",
                _sessionTypeLabel(detail.mode),
              ),
              const SizedBox(height: 10),
              _kv(
                Icons.calendar_today_rounded,
                "Tanggal",
                formatDate(detail.date),
              ),
              const SizedBox(height: 10),
              _kv(
                Icons.login_rounded,
                "Jam Mulai",
                formatTime(detail.startAt),
              ),
              const SizedBox(height: 10),
              _kv(
                Icons.logout_rounded,
                "Jam Selesai",
                formatTime(detail.endAt),
              ),
              const SizedBox(height: 10),
              _kv(
                Icons.person_outline_rounded,
                "Kasir",
                detail.createdBy,
              ),
              if (detail.memberName != null) ...[
                const SizedBox(height: 10),
                _kv(
                  Icons.badge_outlined,
                  "Member",
                  detail.memberName!,
                ),
              ],
              if (detail.promoName != null) ...[
                const SizedBox(height: 10),
                _kv(
                  Icons.local_offer_outlined,
                  "Promo",
                  detail.promoName!,
                ),
              ],
              const SizedBox(height: 10),
              _kv(
                Icons.account_balance_wallet_outlined,
                "Metode Bayar",
                detail.paymentMethod,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _label("Rincian Tagihan"),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _kv(
                Icons.receipt_long_outlined,
                "Subtotal",
                formatCurrency(detail.subTotal),
              ),
              if (detail.discount > 0) ...[
                const SizedBox(height: 10),
                _kv(
                  Icons.local_offer_outlined,
                  "Diskon Promo",
                  "-${formatCurrency(detail.discount)}",
                  valueColor: AppColors.success,
                ),
              ],
              if (detail.tax > 0) ...[
                const SizedBox(height: 10),
                _kv(
                  Icons.percent_rounded,
                  "Pajak",
                  formatCurrency(detail.tax),
                ),
              ],
              const SizedBox(height: 10),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Bayar",
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    formatCurrency(detail.totalBill),
                    style: AppText.title.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineError(String message, {required VoidCallback onRetry}) {
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
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text("Coba Lagi"),
          ),
        ],
      ),
    );
  }

  String _sessionTypeLabel(SessionType? mode) {
    switch (mode) {
      case SessionType.timer:
        return "Timer";
      case SessionType.reguler:
        return "Reguler";
      case null:
        return "-";
    }
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _kv(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textHint),
            const SizedBox(width: 8),
            Text(label, style: AppText.bodySecondary),
          ],
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

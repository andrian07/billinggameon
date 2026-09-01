import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/keep_transaction.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/pin_guard.dart';
import '../data/cafe_repository.dart';
import 'rename_keep_transaction_dialog.dart';

/// Lists transactions parked via Cafe/keep_transaction and lets the cashier
/// pick one back up. Resolves with the full [KeepTransactionDetail] (items
/// included) once selected, or null if the dialog was dismissed.
class KeepTransactionListDialog extends StatefulWidget {
  const KeepTransactionListDialog({super.key});

  @override
  State<KeepTransactionListDialog> createState() =>
      _KeepTransactionListDialogState();
}

class _KeepTransactionListDialogState extends State<KeepTransactionListDialog> {
  final _repository = CafeRepository();

  bool _loading = true;
  String? _error;
  List<KeepTransaction> _transactions = [];
  int? _loadingDetailId;
  int? _deletingId;
  int? _renamingId;

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
      final transactions = await _repository.getKeepTransactions();
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _loading = false;
      });
    } on CafeRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _select(KeepTransaction transaction) async {
    setState(() => _loadingDetailId = transaction.id);

    try {
      final detail = await _repository.getKeepTransactionDetail(transaction.id);
      if (!mounted) return;
      Navigator.of(context).pop(detail);
    } on CafeRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetailId = null;
        _error = e.message;
      });
    }
  }

  Future<void> _rename(KeepTransaction transaction) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => RenameKeepTransactionDialog(
        invoiceNumber: transaction.invoiceNumber,
        currentName: transaction.name,
      ),
    );
    if (newName == null) return;

    setState(() => _renamingId = transaction.id);

    try {
      await _repository.renameKeepTransaction(transaction.id, newName);
      if (!mounted) return;
      setState(() {
        final index = _transactions.indexWhere((t) => t.id == transaction.id);
        if (index != -1) {
          _transactions[index] = newName.isEmpty
              ? transaction.copyWith(clearName: true)
              : transaction.copyWith(name: newName);
        }
        _renamingId = null;
      });
      AppToast.success(context, "Nama pesanan berhasil diubah");
    } on CafeRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _renamingId = null);
      AppToast.error(context, e.message);
    }
  }

  Future<void> _confirmDelete(KeepTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Text("Hapus Pesanan?", style: AppText.title),
        content: Text(
          "Pesanan ${transaction.invoiceNumber} akan dihapus permanen dan tidak bisa dikembalikan.",
          style: AppText.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text("HAPUS"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    if (!await PinGuard.confirm(context)) return;

    setState(() => _deletingId = transaction.id);

    try {
      await _repository.deleteKeepTransaction(transaction.id);
      if (!mounted) return;
      setState(() {
        _transactions.removeWhere((t) => t.id == transaction.id);
        _deletingId = null;
      });
      AppToast.success(context, "Pesanan ${transaction.invoiceNumber} dihapus");
    } on CafeRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _deletingId = null);
      AppToast.error(context, e.message);
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
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
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.pending_actions_rounded,
            color: AppColors.info,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pesanan Tertunda",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                "Pilih pesanan yang ditahan untuk dilanjutkan",
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: AppColors.danger,
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppText.bodySecondary,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _load,
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

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 36,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 10),
            Text(
              "Belum ada pesanan yang ditahan",
              style: AppText.bodySecondary,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          _buildTransactionCard(_transactions[index]),
    );
  }

  Widget _buildTransactionCard(KeepTransaction transaction) {
    final isLoadingDetail = _loadingDetailId == transaction.id;
    final isDeleting = _deletingId == transaction.id;
    final isRenaming = _renamingId == transaction.id;
    final busy =
        _loadingDetailId != null || _deletingId != null || _renamingId != null;
    final tableLabel = (transaction.table != null && transaction.table != 0)
        ? "Meja ${transaction.table}"
        : "-";

    return InkWell(
      onTap: busy ? null : () => _select(transaction),
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.name ?? transaction.invoiceNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          tableLabel,
                          style: AppText.caption.copyWith(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    transaction.name != null
                        ? "${transaction.invoiceNumber} • ${transaction.createdBy} • ${formatDate(transaction.createdAt)} ${formatTime(transaction.createdAt)}"
                        : "${transaction.createdBy} • ${formatDate(transaction.createdAt)} ${formatTime(transaction.createdAt)}",
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatCurrency(transaction.totalBill),
                    style: AppText.body.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 30,
              height: 30,
              child: isRenaming
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : InkWell(
                      onTap: busy ? null : () => _rename(transaction),
                      borderRadius: BorderRadius.circular(8),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 19,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 30,
              height: 30,
              child: isDeleting
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : InkWell(
                      onTap: busy ? null : () => _confirmDelete(transaction),
                      borderRadius: BorderRadius.circular(8),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.danger,
                      ),
                    ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 22,
              height: 22,
              child: isLoadingDetail
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

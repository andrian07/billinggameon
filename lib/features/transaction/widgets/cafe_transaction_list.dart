import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/business_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cafe_receipt.dart';
import '../../../models/cafe_transaction.dart';
import '../../../models/transaction.dart';
import '../../../services/receipt_printer_service.dart';
import '../../../services/session_storage.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/transaction_repository.dart';

class CafeTransactionList extends StatefulWidget {
  const CafeTransactionList({super.key});

  @override
  State<CafeTransactionList> createState() => CafeTransactionListState();
}

class CafeTransactionListState extends State<CafeTransactionList> {
  static const _perPage = 20;

  final _repository = TransactionRepository();
  final _receiptPrinter = ReceiptPrinterService();

  List<CafeTransaction> _transactions = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _loading = true;
  String? _error;
  int? _reprintingId;
  int? _cancelingId;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  /// Reloads the currently displayed page — exposed for
  /// [TransactionPage]'s header refresh button via a [GlobalKey].
  Future<void> refresh() => _load(_currentPage);

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.getCafeTransactions(
        page: page,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _transactions = result.transactions;
        _currentPage = result.pagination.currentPage;
        _totalPages = result.pagination.totalPages;
        _totalItems = result.pagination.totalItems;
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

  Future<void> _reprintReceipt(CafeTransaction transaction) async {
    if (_reprintingId != null) return;

    setState(() => _reprintingId = transaction.id);
    try {
      final detail = await _repository.getCafeTransactionDetail(
        transaction.id,
      );

      await _receiptPrinter.printCafeReceipt(
        CafeReceipt(
          businessName: BusinessInfo.name,
          businessAddress: BusinessInfo.address,
          invoiceNumber: detail.invoiceNumber,
          date: detail.date,
          table: detail.table != null ? "Meja ${detail.table}" : "Takeaway",
          items: [
            for (final item in detail.items)
              CafeReceiptItem(
                name: item.name,
                quantity: item.quantity,
                price: item.price,
                note: item.note,
              ),
          ],
          subtotal: detail.subTotal,
          tax: detail.tax,
          total: detail.totalBill,
          paymentMethod: detail.paymentMethod,
          cashierName: detail.createdBy,
          isReprint: true,
        ),
      );

      if (!mounted) return;
      AppToast.success(
        context,
        "Struk ${transaction.invoiceNumber} berhasil dicetak ulang",
      );
    } on TransactionRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, "Gagal mencetak ulang: $e");
    } finally {
      if (mounted) setState(() => _reprintingId = null);
    }
  }

  Future<void> _cancelTransaction(CafeTransaction transaction) async {
    if (_cancelingId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Text("Batalkan Transaksi?", style: AppText.title),
        content: Text(
          "Transaksi ${transaction.invoiceNumber} akan ditandai dibatalkan, "
          "tidak lagi dihitung ke total transaksi, dan stok item yang "
          "terjual akan dikembalikan.",
          style: AppText.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("TIDAK"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text("YA, BATALKAN"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _cancelingId = transaction.id);
    try {
      final session = await SessionStorage().getSession();
      final createdBy = session?['username']?.toString() ?? "";
      await _repository.cancelCafeTransaction(
        transaction.id,
        createdBy: createdBy,
      );
      if (!mounted) return;
      AppToast.success(
        context,
        "Transaksi ${transaction.invoiceNumber} dibatalkan",
      );
      await _load(_currentPage);
    } on TransactionRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _cancelingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState(_error!);
    }

    return Column(
      children: [
        Container(
          color: AppColors.background.withValues(alpha: .5),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: _header(),
        ),
        const Divider(height: 1),
        Expanded(
          child: _transactions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) => _row(
                    no: (_currentPage - 1) * _perPage + index + 1,
                    transaction: _transactions[index],
                    striped: index.isEven,
                  ),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPagination(),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          Text(message, style: AppText.bodySecondary, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _load(_currentPage),
            child: const Text("Coba Lagi"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_cafe_outlined,
            size: 40,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            "Tidak ada transaksi cafe ditemukan",
            style: AppText.bodySecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final startItem = _totalItems == 0 ? 0 : (_currentPage - 1) * _perPage + 1;
    final endItem = (_currentPage * _perPage).clamp(0, _totalItems);

    return Row(
      children: [
        Text(
          "Menampilkan $startItem-$endItem dari $_totalItems transaksi",
          style: AppText.caption,
        ),
        const Spacer(),
        _pageArrow(
          icon: Icons.chevron_left_rounded,
          onTap: _currentPage > 1 ? () => _load(_currentPage - 1) : null,
        ),
        const SizedBox(width: 10),
        Text(
          "Halaman $_currentPage dari $_totalPages",
          style: AppText.caption,
        ),
        const SizedBox(width: 10),
        _pageArrow(
          icon: Icons.chevron_right_rounded,
          onTap: _currentPage < _totalPages
              ? () => _load(_currentPage + 1)
              : null,
        ),
      ],
    );
  }

  Widget _pageArrow({required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textSecondary : AppColors.textHint,
        ),
      ),
    );
  }

  Widget _header() {
    return _rowLayout(
      no: _headerText("No"),
      invoice: _headerText("No. Invoice"),
      tanggal: _headerText("Tanggal"),
      meja: _headerText("Meja"),
      member: _headerText("Member"),
      total: _headerText("Total", alignEnd: true),
      kasir: _headerText("Kasir"),
      status: _headerText("Status", alignCenter: true),
      aksi: _headerText("Aksi", alignCenter: true),
    );
  }

  Widget _row({
    required int no,
    required CafeTransaction transaction,
    required bool striped,
  }) {
    final cellStyle = AppText.caption.copyWith(fontSize: 13);
    final isCompleted = transaction.status == TransactionStatus.completed;
    final statusColor = isCompleted ? AppColors.success : AppColors.danger;

    return Container(
      color: striped
          ? AppColors.background.withValues(alpha: .3)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _rowLayout(
        no: Text("$no", style: cellStyle),
        invoice: Text(
          transaction.invoiceNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cellStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        tanggal: Text(formatDate(transaction.date), style: cellStyle),
        meja: Text(transaction.table ?? "-", style: cellStyle),
        member: Text(
          transaction.customerName ?? "-",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cellStyle,
        ),
        total: Text(
          formatCurrency(transaction.totalBill),
          textAlign: TextAlign.end,
          style: cellStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        kasir: Text(transaction.createdBy, style: cellStyle),
        status: Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              isCompleted ? "Selesai" : "Dibatalkan",
              style: AppText.caption.copyWith(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        aksi: isCompleted
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.print_outlined,
                    tooltip: "Cetak ulang struk",
                    loading: _reprintingId == transaction.id,
                    onTap: () => _reprintReceipt(transaction),
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.cancel_outlined,
                    tooltip: "Batalkan transaksi",
                    loading: _cancelingId == transaction.id,
                    color: AppColors.danger,
                    onTap: () => _cancelTransaction(transaction),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  static Widget _headerText(
    String text, {
    bool alignEnd = false,
    bool alignCenter = false,
  }) {
    return Text(
      text,
      textAlign: alignCenter
          ? TextAlign.center
          : (alignEnd ? TextAlign.end : TextAlign.start),
      style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
    );
  }

  static Widget _rowLayout({
    required Widget no,
    required Widget invoice,
    required Widget tanggal,
    required Widget meja,
    required Widget member,
    required Widget total,
    required Widget kasir,
    required Widget status,
    required Widget aksi,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 32, child: no),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: invoice),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: tanggal),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: meja),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: member),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: total),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: kasir),
        const SizedBox(width: 12),
        SizedBox(width: 90, child: status),
        const SizedBox(width: 12),
        SizedBox(width: 76, child: aksi),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool loading;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.loading,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        width: 30,
        height: 30,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 15, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/saldo_transaction.dart';
import '../../../models/transaction.dart';
import '../data/transaction_repository.dart';

class SaldoTransactionList extends StatefulWidget {
  const SaldoTransactionList({super.key});

  @override
  State<SaldoTransactionList> createState() => _SaldoTransactionListState();
}

class _SaldoTransactionListState extends State<SaldoTransactionList> {
  static const _perPage = 20;

  final _repository = TransactionRepository();

  List<SaldoTransaction> _transactions = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.getSaldoTransactions(
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
            Icons.savings_outlined,
            size: 40,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            "Tidak ada pengisian saldo ditemukan",
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
      member: _headerText("Member"),
      nominal: _headerText("Nominal", alignEnd: true),
      metode: _headerText("Metode Pembayaran"),
      kasir: _headerText("Kasir"),
      status: _headerText("Status", alignCenter: true),
    );
  }

  Widget _row({
    required int no,
    required SaldoTransaction transaction,
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
        tanggal: Text(formatDate(transaction.createdAt), style: cellStyle),
        member: Text(
          transaction.customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cellStyle,
        ),
        nominal: Text(
          formatCurrency(transaction.nominal),
          textAlign: TextAlign.end,
          style: cellStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.success,
          ),
        ),
        metode: Text(transaction.paymentName, style: cellStyle),
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
    required Widget member,
    required Widget nominal,
    required Widget metode,
    required Widget kasir,
    required Widget status,
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
        Expanded(flex: 2, child: member),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: nominal),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: metode),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: kasir),
        const SizedBox(width: 12),
        SizedBox(width: 90, child: status),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formatters.dart';
import '../../models/pagination_info.dart';
import '../../models/purchase.dart';
import '../../services/session_storage.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/purchase_repository.dart';
import 'purchase_add_page.dart';
import 'widgets/purchase_detail_dialog.dart';

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  static const _perPage = 10;

  final _repository = PurchaseRepository();
  final _sessionStorage = SessionStorage();

  List<Purchase> _purchases = [];
  PaginationInfo _pagination = PaginationInfo.empty;
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
      final result = await _repository.getPurchases(
        page: page,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _purchases = result.purchases;
        _pagination = result.pagination;
        _loading = false;
      });
    } on PurchaseRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _goToPage(int page) {
    if (page == _pagination.currentPage || _loading) return;
    _load(page);
  }

  Future<String> _currentUsername() async {
    final session = await _sessionStorage.getSession();
    return session?['username']?.toString() ?? "";
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Text(title, style: AppText.title),
        content: Text(message, style: AppText.bodySecondary),
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
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openAddDialog() async {
    final result = await context.push<PurchaseFormResult>(
      '/pembelian/tambah',
    );
    if (result == null) return;

    try {
      final createdBy = await _currentUsername();
      await _repository.addPurchase(
        supplier: result.supplier,
        supplierInvoice: result.supplierInvoice,
        createdBy: createdBy,
        items: result.items,
      );
      if (!mounted) return;
      AppToast.success(context, "Pembelian berhasil disimpan");
      await _load(1);
    } on PurchaseRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  void _openDetail(Purchase purchase) {
    showDialog<void>(
      context: context,
      builder: (context) => PurchaseDetailDialog(purchaseId: purchase.id),
    );
  }

  Future<void> _confirmCancel(Purchase purchase) async {
    final confirmed = await _confirm(
      title: "Batalkan Pembelian?",
      message:
          "Apakah Anda yakin akan membatalkan pembelian \"${purchase.invoiceNumber}\"? Stok yang sudah ditambahkan akan dikurangi kembali.",
      confirmLabel: "YA, BATALKAN",
    );
    if (!confirmed) return;

    try {
      final cancelledBy = await _currentUsername();
      await _repository.cancelPurchase(
        purchaseId: purchase.id,
        cancelledBy: cancelledBy,
      );
      if (!mounted) return;
      AppToast.success(context, "Pembelian berhasil dibatalkan");
      await _load(_pagination.currentPage);
    } on PurchaseRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Pembelian",
      subtitle: "Kelola transaksi pembelian stok",
      showSearch: false,
      activeMenuKey: "pembelian",
      onMenuSelect: (key) => navigateToMenu(context, key),
      onRefresh: () => _load(_pagination.currentPage),
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: _buildToolbar(),
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (!_loading && _error == null && _purchases.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 14, 36, 6),
              child: _PurchaseRow.header(),
            ),
          Expanded(child: _buildBody()),
          if (!_loading && _error == null && _purchases.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.divider),
            Container(
              color: AppColors.background.withValues(alpha: .3),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              child: _buildPagination(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState(_error!);
    }
    if (_purchases.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _purchases.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final purchase = _purchases[index];
        return _RowCard(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            onTap: () => _openDetail(purchase),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: _PurchaseRow.data(
                no:
                    (_pagination.currentPage - 1) * _pagination.perPage +
                    index +
                    1,
                purchase: purchase,
                onDetail: () => _openDetail(purchase),
                onCancel: purchase.status == PurchaseStatus.done
                    ? () => _confirmCancel(purchase)
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.shopping_cart_checkout_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Daftar Pembelian",
              style: AppText.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _loading || _error != null
                  ? "Memuat data..."
                  : "${_pagination.totalItems} pembelian tercatat",
              style: AppText.caption,
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _openAddDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              "Tambah Pembelian",
              style: AppText.button.copyWith(fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 30,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 14),
          Text("Belum ada pembelian ditemukan", style: AppText.bodySecondary),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 30,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodySecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _load(_pagination.currentPage),
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

  Widget _buildPagination() {
    final p = _pagination;
    final startItem = p.totalItems == 0
        ? 0
        : (p.currentPage - 1) * p.perPage + 1;
    final endItem = (p.currentPage * p.perPage).clamp(0, p.totalItems);

    return Row(
      children: [
        Text(
          "Menampilkan $startItem-$endItem dari ${p.totalItems} pembelian",
          style: AppText.caption,
        ),
        const Spacer(),
        _pageArrow(
          icon: Icons.chevron_left_rounded,
          onTap: p.hasPrevPage ? () => _goToPage(p.currentPage - 1) : null,
        ),
        const SizedBox(width: 6),
        ..._buildPageButtons(),
        const SizedBox(width: 6),
        _pageArrow(
          icon: Icons.chevron_right_rounded,
          onTap: p.hasNextPage ? () => _goToPage(p.currentPage + 1) : null,
        ),
      ],
    );
  }

  List<Widget> _buildPageButtons() {
    final window = _pageWindow(
      _pagination.totalPages,
      _pagination.currentPage,
    );
    final widgets = <Widget>[];

    for (var i = 0; i < window.length; i++) {
      if (i > 0 && window[i] - window[i - 1] > 1) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text("...", style: AppText.caption),
          ),
        );
      }
      widgets.add(
        _pageNumberButton(
          window[i],
          active: window[i] == _pagination.currentPage,
        ),
      );
      widgets.add(const SizedBox(width: 6));
    }

    return widgets;
  }

  List<int> _pageWindow(int totalPages, int current) {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i + 1);

    final set = <int>{1, totalPages, current};
    if (current - 1 >= 1) set.add(current - 1);
    if (current + 1 <= totalPages) set.add(current + 1);

    return set.toList()..sort();
  }

  Widget _pageNumberButton(int page, {required bool active}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: active ? null : () => _goToPage(page),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          "$page",
          style: AppText.caption.copyWith(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
}

/// Individual row rendered as its own card, with a hover "lift" effect.
class _RowCard extends StatefulWidget {
  final Widget child;

  const _RowCard({required this.child});

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.hover
              : AppColors.background.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: _hovered
                ? AppColors.primary.withValues(alpha: .4)
                : AppColors.border,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  final bool header;
  final int? no;
  final Purchase? purchase;
  final VoidCallback? onDetail;
  final VoidCallback? onCancel;

  const _PurchaseRow.header()
    : header = true,
      no = null,
      purchase = null,
      onDetail = null,
      onCancel = null;

  const _PurchaseRow.data({
    required this.no,
    required this.purchase,
    required this.onDetail,
    required this.onCancel,
  }) : header = false;

  @override
  Widget build(BuildContext context) {
    if (header) {
      return _row(
        no: _headerText("NO"),
        invoice: _headerText("NO. INVOICE"),
        tanggal: _headerText("TANGGAL"),
        supplier: _headerText("SUPPLIER"),
        total: _headerText("TOTAL", alignEnd: true),
        status: _headerText("STATUS", alignCenter: true),
        aksi: _headerText("AKSI", alignCenter: true),
      );
    }

    final p = purchase!;
    final cellStyle = AppText.caption.copyWith(fontSize: 13);
    final isDone = p.status == PurchaseStatus.done;
    final statusColor = isDone ? AppColors.success : AppColors.danger;

    return _row(
      no: Text("$no", style: cellStyle.copyWith(color: AppColors.textHint)),
      invoice: Text(
        p.invoiceNumber,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: cellStyle.copyWith(fontWeight: FontWeight.w600),
      ),
      tanggal: Text(formatDate(p.date), style: cellStyle),
      supplier: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.supplier ?? "-",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: cellStyle,
          ),
          if (p.supplierInvoice != null && p.supplierInvoice!.isNotEmpty)
            Text(
              "No. Inv: ${p.supplierInvoice}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
        ],
      ),
      total: Text(
        formatCurrency(p.total),
        textAlign: TextAlign.end,
        style: cellStyle.copyWith(fontWeight: FontWeight.w600),
      ),
      status: Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            isDone ? "Selesai" : "Dibatalkan",
            style: AppText.caption.copyWith(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      aksi: Center(
        child: PopupMenuButton<String>(
          tooltip: "Aksi",
          color: AppColors.card,
          icon: const Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            side: const BorderSide(color: AppColors.border),
          ),
          onSelected: (value) {
            switch (value) {
              case 'detail':
                onDetail?.call();
                break;
              case 'cancel':
                onCancel?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'detail',
              child: _menuItem(Icons.visibility_outlined, "Detail"),
            ),
            if (onCancel != null)
              PopupMenuItem(
                value: 'cancel',
                child: _menuItem(
                  Icons.cancel_outlined,
                  "Batalkan",
                  color: AppColors.danger,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _menuItem(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppText.body.copyWith(color: color ?? AppColors.text),
        ),
      ],
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
      style: AppText.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: AppColors.textSecondary,
      ),
    );
  }

  static Widget _row({
    required Widget no,
    required Widget invoice,
    required Widget tanggal,
    required Widget supplier,
    required Widget total,
    required Widget status,
    required Widget aksi,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 28, child: no),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: invoice),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: tanggal),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: supplier),
        const SizedBox(width: 10),
        SizedBox(width: 110, child: total),
        const SizedBox(width: 10),
        SizedBox(width: 90, child: status),
        const SizedBox(width: 10),
        SizedBox(width: 48, child: aksi),
      ],
    );
  }
}

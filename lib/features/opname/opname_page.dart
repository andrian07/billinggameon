import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formatters.dart';
import '../../models/pagination_info.dart';
import '../../models/stock_opname.dart';
import '../../services/session_storage.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/opname_repository.dart';
import 'widgets/opname_detail_dialog.dart';

/// Stock opname history — owner-only (see Opname.php on the backend, which
/// rejects opname_add for any account whose userrole isn't 1 regardless of
/// what the client sends). The menu item itself is only visible to the
/// built-in owner account (see app_sidebar.dart), and this page double-checks
/// via [SessionStorage.isSuperadmin] so a direct URL visit doesn't get in.
class OpnamePage extends StatefulWidget {
  const OpnamePage({super.key});

  @override
  State<OpnamePage> createState() => _OpnamePageState();
}

class _OpnamePageState extends State<OpnamePage> {
  static const _perPage = 10;

  final _repository = OpnameRepository();
  final _sessionStorage = SessionStorage();

  bool? _isOwner;
  List<StockOpname> _opnames = [];
  PaginationInfo _pagination = PaginationInfo.empty;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final isOwner = await _sessionStorage.isSuperadmin();
    if (!mounted) return;
    setState(() => _isOwner = isOwner);
    if (isOwner) _load(1);
  }

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.getOpnames(
        page: page,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _opnames = result.opnames;
        _pagination = result.pagination;
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

  void _goToPage(int page) {
    if (page == _pagination.currentPage || _loading) return;
    _load(page);
  }

  Future<void> _openAddPage() async {
    final saved = await context.push<bool>('/opname/tambah');
    if (saved == true) {
      if (!mounted) return;
      AppToast.success(context, "Stock opname berhasil disimpan");
      await _load(1);
    }
  }

  void _openDetail(StockOpname opname) {
    showDialog<void>(
      context: context,
      builder: (context) => OpnameDetailDialog(opnameId: opname.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Stock Opname",
      subtitle: "Rekonsiliasi stok fisik vs sistem",
      showSearch: false,
      activeMenuKey: "opname",
      onMenuSelect: (key) => navigateToMenu(context, key),
      onRefresh: _isOwner == true ? () => _load(_pagination.currentPage) : null,
      child: _isOwner == null
          ? const Center(child: CircularProgressIndicator())
          : (_isOwner == false ? _buildAccessDenied() : _buildCard()),
    );
  }

  Widget _buildAccessDenied() {
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
              Icons.lock_outline_rounded,
              size: 30,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          Text("Hanya akun owner yang dapat mengakses halaman ini", style: AppText.bodySecondary),
        ],
      ),
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
          if (!_loading && _error == null && _opnames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 14, 36, 6),
              child: _OpnameRow.header(),
            ),
          Expanded(child: _buildBody()),
          if (!_loading && _error == null && _opnames.isNotEmpty) ...[
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
    if (_opnames.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _opnames.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final opname = _opnames[index];
        return _RowCard(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            onTap: () => _openDetail(opname),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _OpnameRow.data(no: index + 1, opname: opname),
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
            Icons.fact_check_outlined,
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
              "Riwayat Opname",
              style: AppText.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _loading
                  ? "Memuat data..."
                  : "${_pagination.totalItems} opname tercatat",
              style: AppText.caption,
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _openAddPage,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text("OPNAME BARU"),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: AppText.button.copyWith(fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
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
              Icons.fact_check_outlined,
              size: 30,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 14),
          Text("Belum ada opname tercatat", style: AppText.bodySecondary),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Halaman ${_pagination.currentPage} dari ${_pagination.totalPages == 0 ? 1 : _pagination.totalPages}",
          style: AppText.caption,
        ),
        Row(
          children: [
            OutlinedButton(
              onPressed: _pagination.hasPrevPage
                  ? () => _goToPage(_pagination.currentPage - 1)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.chevron_left_rounded, size: 18),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _pagination.hasNextPage
                  ? () => _goToPage(_pagination.currentPage + 1)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.chevron_right_rounded, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}

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
        ),
        child: widget.child,
      ),
    );
  }
}

class _OpnameRow extends StatelessWidget {
  final bool header;
  final int? no;
  final StockOpname? opname;

  const _OpnameRow.header() : header = true, no = null, opname = null;

  const _OpnameRow.data({required this.no, required this.opname})
    : header = false;

  @override
  Widget build(BuildContext context) {
    if (header) {
      return _row(
        no: _headerText("No"),
        invoice: _headerText("No. Opname"),
        tanggal: _headerText("Tanggal"),
        catatan: _headerText("Catatan"),
        kasir: _headerText("Dibuat Oleh"),
      );
    }

    final o = opname!;
    final cellStyle = AppText.caption.copyWith(fontSize: 12.5);

    return _row(
      no: Text("$no", style: cellStyle.copyWith(color: AppColors.textHint)),
      invoice: Text(
        o.invoiceNumber,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: cellStyle.copyWith(fontWeight: FontWeight.w600),
      ),
      tanggal: Text(formatDate(o.date), style: cellStyle),
      catatan: Text(
        o.note ?? "-",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: cellStyle.copyWith(color: AppColors.textHint),
      ),
      kasir: Text(o.createdBy, maxLines: 1, overflow: TextOverflow.ellipsis, style: cellStyle),
    );
  }

  static Widget _headerText(String text) {
    return Text(
      text,
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
    required Widget catatan,
    required Widget kasir,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 28, child: no),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: invoice),
        const SizedBox(width: 10),
        Expanded(child: tanggal),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: catatan),
        const SizedBox(width: 10),
        Expanded(child: kasir),
      ],
    );
  }
}

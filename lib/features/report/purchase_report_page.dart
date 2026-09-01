import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formatters.dart';
import '../../models/report.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/report_repository.dart';

/// Rekap pembelian stok — Report/purchase_report, dengan filter tanggal
/// (wajib) dan supplier, serta export ke Excel/PDF.
class PurchaseReportPage extends StatefulWidget {
  const PurchaseReportPage({super.key});

  @override
  State<PurchaseReportPage> createState() => _PurchaseReportPageState();
}

class _PurchaseReportPageState extends State<PurchaseReportPage> {
  final _repository = ReportRepository();

  late DateTime _dateFrom;
  late DateTime _dateTo;
  String? _selectedSupplier;

  List<String> _suppliers = [];

  bool _loading = true;
  String? _error;
  PurchaseReportResult? _result;

  bool _exportingExcel = false;
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _dateTo = today;
    _dateFrom = DateTime(today.year, today.month, 1);
    _loadFiltersAndReport();
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> _loadFiltersAndReport() async {
    try {
      final suppliers = await _repository.getPurchaseSuppliers();
      if (!mounted) return;
      setState(() => _suppliers = suppliers);
    } catch (_) {
      // Filter dropdown gagal dimuat bukan alasan untuk memblokir laporannya sendiri.
    }
    await _runReport();
  }

  Future<void> _runReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.getPurchaseReport(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        supplier: _selectedSupplier,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on ReportRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _pickDateFrom() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: _dateTo,
      initialDate: _dateFrom,
    );
    if (result == null) return;
    setState(() => _dateFrom = _dateOnly(result));
  }

  Future<void> _pickDateTo() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      firstDate: _dateFrom,
      lastDate: now,
      initialDate: _dateTo,
    );
    if (result == null) return;
    setState(() => _dateTo = _dateOnly(result));
  }

  Future<void> _export(String type) async {
    setState(() {
      if (type == "excel") {
        _exportingExcel = true;
      } else {
        _exportingPdf = true;
      }
    });

    try {
      final file = await _repository.exportPurchaseReport(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        supplier: _selectedSupplier,
        type: type,
      );
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: "Simpan Laporan Pembelian",
        fileName: file.filename,
        bytes: file.bytes,
      );
      if (!mounted) return;
      if (savePath != null) {
        AppToast.success(context, "Laporan berhasil disimpan");
      }
    } on ReportRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } finally {
      if (mounted) {
        setState(() {
          if (type == "excel") {
            _exportingExcel = false;
          } else {
            _exportingPdf = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Laporan Pembelian",
      subtitle: "Rekap pembelian stok",
      showSearch: false,
      activeMenuKey: "laporan_pembelian",
      onMenuSelect: (key) => navigateToMenu(context, key),
      onRefresh: _loadFiltersAndReport,
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
            child: _buildFilterBar(),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        _dateField(label: "Dari Tanggal", value: _dateFrom, onTap: _pickDateFrom),
        _dateField(label: "Sampai Tanggal", value: _dateTo, onTap: _pickDateTo),
        SizedBox(width: 200, child: _supplierDropdown()),
        SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _runReport,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text("Tampilkan"),
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
        SizedBox(
          height: 42,
          child: OutlinedButton.icon(
            onPressed: (_result == null || _exportingExcel || _exportingPdf)
                ? null
                : () => _export("excel"),
            icon: _exportingExcel
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.grid_on_rounded, size: 18),
            label: const Text("Excel"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.success,
              side: BorderSide(color: AppColors.success.withValues(alpha: .4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: OutlinedButton.icon(
            onPressed: (_result == null || _exportingExcel || _exportingPdf)
                ? null
                : () => _export("pdf"),
            icon: _exportingPdf
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text("PDF"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: .4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.caption.copyWith(fontSize: 9)),
                Text(
                  formatDate(value),
                  style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _supplierDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedSupplier,
      dropdownColor: AppColors.card,
      style: AppText.caption,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.textSecondary,
      ),
      decoration: _filterDecoration(
        hint: "Semua Supplier",
        icon: Icons.storefront_outlined,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text("Semua Supplier"),
        ),
        for (final supplier in _suppliers)
          DropdownMenuItem<String?>(
            value: supplier,
            child: Text(supplier, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => _selectedSupplier = value),
    );
  }

  InputDecoration _filterDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildMessageState(
        icon: Icons.cloud_off_rounded,
        iconColor: AppColors.danger,
        message: _error!,
        action: OutlinedButton.icon(
          onPressed: _runReport,
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
      );
    }

    final result = _result;
    if (result == null || result.rows.isEmpty) {
      return _buildMessageState(
        icon: Icons.shopping_cart_outlined,
        iconColor: AppColors.textHint,
        message: "Tidak ada pembelian pada rentang tanggal ini",
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: _PurchaseReportRowWidget.header(),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            itemCount: result.rows.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              color: AppColors.divider,
            ),
            itemBuilder: (context, index) =>
                _PurchaseReportRowWidget.data(no: index + 1, row: result.rows[index]),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Container(
          color: AppColors.background.withValues(alpha: .4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: _buildSummary(result.summary),
        ),
      ],
    );
  }

  Widget _buildSummary(PurchaseReportSummary summary) {
    return Row(
      children: [
        _summaryStat("Jumlah Nota", "${summary.invoiceCount}"),
        const SizedBox(width: 28),
        _summaryStat("Subtotal", formatCurrency(summary.totalSubTotal)),
        const SizedBox(width: 28),
        _summaryStat("Diskon", formatCurrency(summary.totalDiscount)),
        const Spacer(),
        _summaryStat(
          "Total Pembelian",
          formatCurrency(summary.totalBill),
          emphasize: true,
        ),
      ],
    );
  }

  Widget _summaryStat(String label, String value, {bool emphasize = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: emphasize
              ? AppText.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                )
              : AppText.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required Color iconColor,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: iconColor),
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
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }
}

class _PurchaseReportRowWidget extends StatelessWidget {
  final bool header;
  final int? no;
  final PurchaseReportRow? row;

  const _PurchaseReportRowWidget.header() : header = true, no = null, row = null;

  const _PurchaseReportRowWidget.data({required this.no, required this.row})
    : header = false;

  @override
  Widget build(BuildContext context) {
    if (header) {
      return _row(
        no: _headerText("No"),
        invoice: _headerText("No. Invoice"),
        tanggal: _headerText("Tanggal"),
        supplier: _headerText("Supplier"),
        subTotal: _headerText("Subtotal", alignEnd: true),
        diskon: _headerText("Diskon", alignEnd: true),
        total: _headerText("Total", alignEnd: true),
        status: _headerText("Status", alignCenter: true),
      );
    }

    final r = row!;
    final cellStyle = AppText.caption.copyWith(fontSize: 12.5);
    final isDone = r.status.toLowerCase() == "done";
    final statusColor = isDone ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: _row(
        no: Text("$no", style: cellStyle.copyWith(color: AppColors.textHint)),
        invoice: Text(
          r.invoiceNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cellStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        tanggal: Text(formatDate(r.date), style: cellStyle),
        supplier: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              r.supplier ?? "-",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cellStyle,
            ),
            if (r.supplierInvoice != null && r.supplierInvoice!.isNotEmpty)
              Text(
                "No. Inv: ${r.supplierInvoice}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.textHint,
                ),
              ),
          ],
        ),
        subTotal: Text(
          formatCurrency(r.subTotal),
          textAlign: TextAlign.end,
          style: cellStyle,
        ),
        diskon: Text(
          r.discount > 0 ? "-${formatCurrency(r.discount)}" : "-",
          textAlign: TextAlign.end,
          style: cellStyle.copyWith(
            color: r.discount > 0 ? AppColors.success : AppColors.textHint,
          ),
        ),
        total: Text(
          formatCurrency(r.total),
          textAlign: TextAlign.end,
          style: cellStyle.copyWith(fontWeight: FontWeight.w700),
        ),
        status: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                r.status,
                style: AppText.caption.copyWith(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!isDone && r.cancelledBy != null) ...[
              const SizedBox(height: 2),
              Tooltip(
                message: "Dibatalkan oleh ${r.cancelledBy}",
                child: Text(
                  "oleh ${r.cancelledBy}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    fontSize: 9,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ],
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
      style: AppText.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .4,
        color: AppColors.textSecondary,
      ),
    );
  }

  static Widget _row({
    required Widget no,
    required Widget invoice,
    required Widget tanggal,
    required Widget supplier,
    required Widget subTotal,
    required Widget diskon,
    required Widget total,
    required Widget status,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 32, child: no),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: invoice),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: tanggal),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: supplier),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: subTotal),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: diskon),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: total),
        const SizedBox(width: 12),
        SizedBox(width: 90, child: status),
      ],
    );
  }
}

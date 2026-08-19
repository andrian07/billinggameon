import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../models/report.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/report_repository.dart';

/// Rekap stok produk saat ini — Report/stock. Tidak ada filter tanggal;
/// hanya "view" (default) atau export Excel/PDF.
class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  final _repository = ReportRepository();

  bool _loading = true;
  String? _error;
  List<StockReportRow> _rows = [];

  bool _exportingExcel = false;
  bool _exportingPdf = false;

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
      final rows = await _repository.getStockReport();
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  Future<void> _export(String type) async {
    setState(() {
      if (type == "excel") {
        _exportingExcel = true;
      } else {
        _exportingPdf = true;
      }
    });

    try {
      final file = await _repository.exportStockReport(type: type);
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: "Simpan Laporan Stok",
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
      title: "Laporan Stok",
      subtitle: "Rekap stok produk saat ini",
      showSearch: false,
      activeMenuKey: "laporan_stok",
      onMenuSelect: (key) => navigateToMenu(context, key),
      onRefresh: _load,
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
          Expanded(child: _buildBody()),
        ],
      ),
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
            Icons.bar_chart_rounded,
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
              "Daftar Stok Produk",
              style: AppText.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _loading ? "Memuat data..." : "${_rows.length} produk",
              style: AppText.caption,
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: (_loading || _exportingExcel || _exportingPdf)
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
        const SizedBox(width: 10),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: (_loading || _exportingExcel || _exportingPdf)
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
        const SizedBox(width: 10),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Muat Ulang"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
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
      return _buildMessageState(
        icon: Icons.cloud_off_rounded,
        iconColor: AppColors.danger,
        message: _error!,
        action: OutlinedButton.icon(
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
      );
    }

    if (_rows.isEmpty) {
      return _buildMessageState(
        icon: Icons.inventory_2_outlined,
        iconColor: AppColors.textHint,
        message: "Belum ada data stok produk",
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: _StockReportRowWidget.header(),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              color: AppColors.divider,
            ),
            itemBuilder: (context, index) =>
                _StockReportRowWidget.data(no: index + 1, row: _rows[index]),
          ),
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

class _StockReportRowWidget extends StatelessWidget {
  final bool header;
  final int? no;
  final StockReportRow? row;

  const _StockReportRowWidget.header() : header = true, no = null, row = null;

  const _StockReportRowWidget.data({required this.no, required this.row})
    : header = false;

  @override
  Widget build(BuildContext context) {
    if (header) {
      return _row(
        no: _headerText("No"),
        code: _headerText("Kode Produk"),
        name: _headerText("Nama Produk"),
        stock: _headerText("Total Stok", alignEnd: true),
      );
    }

    final r = row!;
    final cellStyle = AppText.caption.copyWith(fontSize: 12.5);
    final lowStock = r.totalStock <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: _row(
        no: Text("$no", style: cellStyle.copyWith(color: AppColors.textHint)),
        code: Text(
          r.productCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cellStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        name: Text(
          r.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cellStyle,
        ),
        stock: Text(
          "${r.totalStock}",
          textAlign: TextAlign.end,
          style: cellStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: lowStock ? AppColors.danger : AppColors.text,
          ),
        ),
      ),
    );
  }

  static Widget _headerText(String text, {bool alignEnd = false}) {
    return Text(
      text,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: AppText.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .4,
        color: AppColors.textSecondary,
      ),
    );
  }

  static Widget _row({
    required Widget no,
    required Widget code,
    required Widget name,
    required Widget stock,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 32, child: no),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: code),
        const SizedBox(width: 12),
        Expanded(flex: 4, child: name),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: stock),
      ],
    );
  }
}

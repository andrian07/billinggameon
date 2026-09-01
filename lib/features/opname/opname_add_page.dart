import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../models/stock_opname.dart';
import '../../services/session_storage.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/opname_repository.dart';

class _OpnameRowInput {
  final OpnameProduct product;
  final TextEditingController controller;

  _OpnameRowInput(this.product)
    : controller = TextEditingController(text: "${product.systemStock}");

  int get physicalStock => int.tryParse(controller.text.trim()) ?? 0;
  int get difference => physicalStock - product.systemStock;

  void dispose() => controller.dispose();
}

/// Full page (pushed via GoRouter) for recording a stock opname — every
/// stock-tracked product is pre-filled with its current system stock so the
/// owner only has to correct the ones that actually differ after a physical
/// count. Pops `true` on save so the caller (OpnamePage) knows to refresh.
class OpnameAddPage extends StatefulWidget {
  const OpnameAddPage({super.key});

  @override
  State<OpnameAddPage> createState() => _OpnameAddPageState();
}

class _OpnameAddPageState extends State<OpnameAddPage> {
  final _repository = OpnameRepository();
  final _sessionStorage = SessionStorage();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();

  List<_OpnameRowInput> _rows = [];
  String _search = "";
  bool _loading = true;
  String? _loadError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final products = await _repository.getProducts();
      if (!mounted) return;
      setState(() {
        _rows = [for (final p in products) _OpnameRowInput(p)];
        _loading = false;
      });
    } on OpnameRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  List<_OpnameRowInput> get _filteredRows {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _rows;
    return _rows
        .where(
          (r) =>
              r.product.name.toLowerCase().contains(query) ||
              r.product.code.toLowerCase().contains(query),
        )
        .toList();
  }

  int get _changedCount => _rows.where((r) => r.difference != 0).length;

  Future<void> _submit() async {
    if (_submitting || _rows.isEmpty) return;

    setState(() => _submitting = true);

    try {
      final session = await _sessionStorage.getSession();
      final userId = int.tryParse(session?['id']?.toString() ?? "") ?? 0;
      final createdBy = session?['username']?.toString() ?? "";

      await _repository.addOpname(
        userId: userId,
        note: _noteController.text,
        createdBy: createdBy,
        items: [
          for (final row in _rows)
            OpnameItemInput(
              productId: row.product.id,
              physicalStock: row.physicalStock,
            ),
        ],
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on OpnameRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Opname Baru",
      subtitle: "Catat hasil hitung stok fisik",
      showSearch: false,
      activeMenuKey: "opname",
      onMenuSelect: (key) => navigateToMenu(context, key),
      child: AppCard(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              style: AppText.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadProducts,
              child: const Text("Coba Lagi"),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                style: AppText.body,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: "Cari nama atau kode produk...",
                  prefixIcon: Icon(Icons.search, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _noteController,
                style: AppText.body,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: "Catatan (opsional)",
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              "${_rows.length} produk · $_changedCount berbeda dari stok sistem",
              style: AppText.caption,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: AppColors.divider, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _headerRow(),
        ),
        Expanded(
          child: _rows.isEmpty
              ? Center(
                  child: Text(
                    "Tidak ada produk dengan pelacakan stok",
                    style: AppText.bodySecondary,
                  ),
                )
              : ListView.separated(
                  itemCount: _filteredRows.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (context, index) =>
                      _buildRow(_filteredRows[index]),
                ),
        ),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _rows.isEmpty || _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 20),
            label: Text(_submitting ? "MENYIMPAN..." : "SIMPAN OPNAME"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.textHint,
              minimumSize: const Size(0, 48),
              elevation: 0,
              textStyle: AppText.button,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerRow() {
    TextStyle style = AppText.caption.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: .6,
      color: AppColors.textSecondary,
    );
    return Row(
      children: [
        Expanded(flex: 3, child: Text("PRODUK", style: style)),
        Expanded(
          child: Text("STOK SISTEM", textAlign: TextAlign.end, style: style),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text("STOK FISIK", textAlign: TextAlign.center, style: style),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text("SELISIH", textAlign: TextAlign.end, style: style),
        ),
      ],
    );
  }

  Widget _buildRow(_OpnameRowInput row) {
    final diff = row.difference;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  row.product.unitName ?? row.product.code,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              "${row.product.systemStock}",
              textAlign: TextAlign.end,
              style: AppText.body,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: row.controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              diffText,
              textAlign: TextAlign.end,
              style: AppText.body.copyWith(
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

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cafe_promo.dart';
import '../../../models/pagination_info.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/cafe_promo_repository.dart';
import 'cafe_promo_form_dialog.dart';

/// Isi tab "Promo Cafe" di halaman Promo - daftar + CRUD promo cafe.
/// Berdiri sendiri (repo & paginasinya sendiri) supaya tidak mengganggu
/// daftar promo billing yang sudah ada.
class CafePromoSection extends StatefulWidget {
  const CafePromoSection({super.key});

  @override
  State<CafePromoSection> createState() => _CafePromoSectionState();
}

class _CafePromoSectionState extends State<CafePromoSection> {
  static const _perPage = 10;

  final _repository = CafePromoRepository();

  List<CafePromo> _promos = [];
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
      final result = await _repository.getPromos(page: page, perPage: _perPage);
      if (!mounted) return;
      setState(() {
        _promos = result.promos;
        _pagination = result.pagination;
        _loading = false;
      });
    } on CafePromoRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openAdd() async {
    final result = await showDialog<CafePromoFormResult>(
      context: context,
      builder: (_) => const CafePromoFormDialog(),
    );
    if (result == null) return;
    try {
      await _repository.addPromo(
        name: result.name,
        price: result.price,
        productIds: result.productIds,
      );
      if (!mounted) return;
      AppToast.success(context, "Promo cafe ${result.name} ditambahkan");
      await _load(1);
    } on CafePromoRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  Future<void> _openEdit(CafePromo promo) async {
    final result = await showDialog<CafePromoFormResult>(
      context: context,
      builder: (_) => CafePromoFormDialog(promo: promo),
    );
    if (result == null) return;
    try {
      await _repository.editPromo(
        id: promo.id,
        name: result.name,
        price: result.price,
        productIds: result.productIds,
      );
      if (!mounted) return;
      AppToast.success(context, "Promo cafe ${result.name} diperbarui");
      await _load(_pagination.currentPage);
    } on CafePromoRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  Future<void> _confirmDelete(CafePromo promo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Text("Hapus Promo Cafe?", style: AppText.title),
        content: Text(
          "Hapus promo cafe \"${promo.name}\"?",
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
            child: const Text("YA, HAPUS"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repository.deletePromo(promo.id);
      if (!mounted) return;
      AppToast.success(context, "Promo cafe ${promo.name} dihapus");
      await _load(_pagination.currentPage);
    } on CafePromoRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: Row(
            children: [
              Text(
                _loading || _error != null
                    ? "Memuat data..."
                    : "${_pagination.totalItems} promo cafe terdaftar",
                style: AppText.caption,
              ),
              const Spacer(),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: _openAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    "Tambah Promo Cafe",
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
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(child: _buildBody()),
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
            const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 30),
            const SizedBox(height: 12),
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
              onPressed: () => _load(_pagination.currentPage),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Coba Lagi"),
            ),
          ],
        ),
      );
    }
    if (_promos.isEmpty) {
      return Center(
        child: Text("Belum ada promo cafe", style: AppText.bodySecondary),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: _promos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = _promos[index];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.name,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p.items.isEmpty
                          ? "${p.productIds.length} produk"
                          : p.items.map((i) => i.productName).join(", "),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatCurrency(p.price),
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: "Aksi",
                color: AppColors.card,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onSelected: (v) {
                  if (v == 'edit') _openEdit(p);
                  if (v == 'delete') _confirmDelete(p);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text("Edit")),
                  PopupMenuItem(value: 'delete', child: Text("Hapus")),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

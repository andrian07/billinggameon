import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../features/attendance/widgets/absensi_scan_dialog.dart';
import '../../features/billing/data/billing_repository.dart';
import '../../features/cashier/widgets/tutup_kas_dialog.dart';
import '../../services/session_storage.dart';
import 'app_toast.dart';

class AppHeader extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool showSearch;
  final VoidCallback? onRefresh;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showSearch = true,
    this.onRefresh,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  String _username = "";
  String _roleName = "";

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionStorage().getSession();
    if (!mounted) return;
    setState(() {
      _username = session?['username']?.toString() ?? "";
      _roleName = session?['roleName']?.toString() ?? "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.header,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: AppText.heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subtitle != null)
                  Text(
                    widget.subtitle!,
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          if (widget.showSearch) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search...",
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],

          if (widget.onRefresh != null) ...[
            IconButton(
              tooltip: "Refresh",
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],

          OutlinedButton.icon(
            onPressed: () => _openAbsensiScan(context),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text("Absensi"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),

          const SizedBox(width: 8),

          OutlinedButton.icon(
            onPressed: () => _openTutupKas(context),
            icon: const Icon(Icons.summarize_rounded, size: 18),
            label: const Text("Tutup Kas"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            tooltip: "Reset Lampu",
            onPressed: () => _resetLampu(context),
            icon: const Icon(Icons.lightbulb_outline),
          ),

          const SizedBox(width: 8),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _username.isNotEmpty ? _username : "...",
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (_roleName.isNotEmpty)
                    Text(_roleName, style: AppText.caption),
                ],
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openAbsensiScan(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AbsensiScanDialog(),
    );
  }

  Future<void> _openTutupKas(BuildContext context) async {
    final session = await SessionStorage().getSession();
    final userId = int.tryParse(session?['id']?.toString() ?? "") ?? 0;
    final cashierName = session?['username']?.toString() ?? "Kasir";

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => TutupKasDialog(userId: userId, cashierName: cashierName),
    );
  }

  Future<void> _resetLampu(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Text("Reset Lampu Meja?", style: AppText.title),
        content: Text(
          "Lampu setiap meja akan disinkronkan ulang sesuai status saat ini, "
          "diproses satu per satu. Proses ini butuh beberapa detik dan tidak "
          "bisa dibatalkan di tengah jalan.",
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("YA, RESET"),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Non-dismissible: the barrier itself blocks every button underneath
    // (tap and keyboard) for as long as the sequential relay reset is
    // running on the backend.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text("Mereset lampu meja...", style: AppText.body),
              ],
            ),
          ),
        ),
      ),
    );

    String? errorMessage;
    var resultMessage = "Reset lampu selesai";
    try {
      resultMessage = await BillingRepository().resetLampu();
    } on BillingRepositoryException catch (e) {
      errorMessage = e.message;
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (errorMessage != null) {
      AppToast.error(context, errorMessage);
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Text("Berhasil", style: AppText.title),
          ],
        ),
        content: Text(resultMessage, style: AppText.bodySecondary),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

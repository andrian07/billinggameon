import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/payment_method.dart';
import '../../../models/topup_request.dart';
import '../../../services/session_storage.dart';
import '../../../services/topup_watcher.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../payment/data/payment_method_repository.dart';
import '../data/topup_repository.dart';

class TopupRequestsDialog extends StatefulWidget {
  const TopupRequestsDialog({super.key});

  @override
  State<TopupRequestsDialog> createState() => _TopupRequestsDialogState();
}

class _TopupRequestsDialogState extends State<TopupRequestsDialog> {
  final _repository = TopupRepository();
  final _paymentMethodRepository = PaymentMethodRepository();

  static const _refreshInterval = Duration(seconds: 5);

  bool _loading = true;
  String? _loadError;
  List<TopupRequest> _requests = [];
  List<PaymentMethod> _paymentMethods = [];
  final Set<int> _approving = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh so a request submitted from the member app shows up here
    // without the cashier having to reopen the dialog.
    _timer = Timer.periodic(_refreshInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// [silent] keeps the current list on screen (no spinner) - used by the
  /// 5-second auto-refresh so the list doesn't flicker on every tick.
  Future<void> _load({bool silent = false}) async {
    if (_approving.isNotEmpty) return; // don't yank rows mid-approve
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final requests = await _repository.getPendingTopups();
      final paymentMethods = await _paymentMethodRepository.getPaymentMethods();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _paymentMethods = paymentMethods;
        _loading = false;
        _loadError = null;
      });
      // What's on screen has now been seen by a cashier - clear the badge.
      await _repository.markNotificationRead();
      TopupWatcher.instance.refreshNow();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _loadError = e.toString();
      });
    }
  }

  /// Tapping a notification row opens the approve confirmation - the cashier
  /// picks which payment method the money actually came in through, then
  /// confirms. Nothing is approved just by opening this.
  Future<void> _confirmApprove(TopupRequest request) async {
    if (_approving.contains(request.topupRequestId)) return;

    final paymentId = await showDialog<int>(
      context: context,
      builder: (_) => _ApproveConfirmDialog(
        request: request,
        paymentMethods: _paymentMethods,
      ),
    );

    if (paymentId == null) return; // cancelled
    await _approve(request, paymentId);
  }

  Future<void> _approve(TopupRequest request, int paymentId) async {
    if (paymentId <= 0) {
      AppToast.error(context, "Pilih metode pembayaran dulu");
      return;
    }

    setState(() => _approving.add(request.topupRequestId));

    try {
      final session = await SessionStorage().getSession();
      final createdBy = session?['username']?.toString() ?? "";
      final paidBy = int.tryParse(session?['id']?.toString() ?? "") ?? 0;

      await _repository.approveTopup(
        topupRequestId: request.topupRequestId,
        paymentId: paymentId,
        createdBy: createdBy,
        paidBy: paidBy,
      );

      if (!mounted) return;
      setState(() {
        _requests.removeWhere((r) => r.topupRequestId == request.topupRequestId);
        _approving.remove(request.topupRequestId);
      });
      AppToast.success(
        context,
        "Top up ${request.customerName} sebesar ${formatCurrency(request.amount)} disetujui",
      );
      // Refresh the header badge right away instead of waiting for the next poll tick.
      TopupWatcher.instance.refreshNow();
    } catch (e) {
      if (!mounted) return;
      setState(() => _approving.remove(request.topupRequestId));
      AppToast.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text("Permintaan Top Up", style: AppText.title),
                  ),
                  IconButton(
                    tooltip: "Tutup",
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (!_loading && _loadError == null && _requests.isNotEmpty) ...[
                const SizedBox(height: AppSizes.xs),
                Text(
                  "Ketuk salah satu untuk menyetujui",
                  style: AppText.caption,
                ),
              ],
              const SizedBox(height: AppSizes.sm),
              Flexible(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(_loadError!, style: AppText.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.sm),
            OutlinedButton(onPressed: _load, child: const Text("Coba Lagi")),
          ],
        ),
      );
    }

    if (_requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text("Belum ada permintaan top up", style: AppText.bodySecondary),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _requests.length,
      separatorBuilder: (_, _) => const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) => _buildRow(_requests[index]),
    );
  }

  Widget _buildRow(TopupRequest request) {
    final isApproving = _approving.contains(request.topupRequestId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.xs,
        vertical: AppSizes.xs,
      ),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: .12),
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        request.customerName,
        style: AppText.body.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        "${request.customerPhone} · via ${request.paymentMethod}",
        style: AppText.caption,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isApproving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(request.amount),
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
      onTap: isApproving ? null : () => _confirmApprove(request),
    );
  }
}

/// Confirmation shown after tapping a top-up notification row. Returns the
/// chosen payment method id when the cashier confirms, or null on cancel.
class _ApproveConfirmDialog extends StatefulWidget {
  final TopupRequest request;
  final List<PaymentMethod> paymentMethods;

  const _ApproveConfirmDialog({
    required this.request,
    required this.paymentMethods,
  });

  @override
  State<_ApproveConfirmDialog> createState() => _ApproveConfirmDialogState();
}

class _ApproveConfirmDialogState extends State<_ApproveConfirmDialog> {
  int? _selectedPaymentId;

  @override
  void initState() {
    super.initState();
    _selectedPaymentId = widget.paymentMethods.isNotEmpty
        ? widget.paymentMethods.first.id
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      title: const Text("Setujui Top Up?"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow("Member", request.customerName),
          _infoRow("No. HP", request.customerPhone),
          _infoRow("Nominal", formatCurrency(request.amount)),
          _infoRow("Diajukan via", request.paymentMethod),
          const SizedBox(height: AppSizes.md),
          DropdownButtonFormField<int>(
            initialValue: _selectedPaymentId,
            isDense: true,
            decoration: const InputDecoration(
              labelText: "Diterima via",
              isDense: true,
            ),
            items: widget.paymentMethods
                .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                .toList(),
            onChanged: (value) => setState(() => _selectedPaymentId = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Batal"),
        ),
        ElevatedButton(
          onPressed: (_selectedPaymentId ?? 0) <= 0
              ? null
              : () => Navigator.of(context).pop(_selectedPaymentId),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          child: const Text("Setujui"),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: AppText.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

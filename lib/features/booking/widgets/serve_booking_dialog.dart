import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/booking_request.dart';
import '../../../models/pool_table.dart';
import '../../../services/session_storage.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/data/table_repository.dart';

/// Opens the physical table that matches a booking's room category, using
/// EXACTLY the slot the member booked (start time + duration from the
/// booking) - not "now". Returns true once the table is booked.
class ServeBookingDialog extends StatefulWidget {
  final BookingRequest booking;

  const ServeBookingDialog({super.key, required this.booking});

  @override
  State<ServeBookingDialog> createState() => _ServeBookingDialogState();
}

class _ServeBookingDialogState extends State<ServeBookingDialog> {
  final _tableRepository = TableRepository();
  final _billingRepository = BillingRepository();

  bool _loading = true;
  String? _loadError;
  List<PoolTable> _freeTables = [];
  PoolTable? _selectedTable;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final tables = await _tableRepository.getTables();
      final free = tables
          .where(
            (t) =>
                t.status == TableStatus.ready &&
                t.categoryMejaId == widget.booking.categoryMejaId,
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _freeTables = free;
        _selectedTable = free.isNotEmpty ? free.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    final table = _selectedTable;
    final startAt = widget.booking.startAt;
    if (table == null || startAt == null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final session = await SessionStorage().getSession();
      final createdBy = session?['username']?.toString() ?? "";
      final duration = Duration(hours: widget.booking.durationHours);

      await _billingRepository.bookTable(
        tableId: table.id,
        mode: SessionType.timer,
        // Slot PERSIS sesuai yang di-booking member - bukan jam kasir menekan
        // tombol ini - supaya durasi yang sudah dibayar (saldo terpotong di
        // gameon saat booking dibuat) tidak bergeser.
        startTime: startAt,
        endTime: startAt.add(duration),
        duration: duration,
        customerId: widget.booking.customerId,
        createdBy: createdBy,
        // kasir memang sedang melayani booking ini - jangan ditahan oleh
        // peringatan "bentrok dengan booking member" (yaitu booking ini sendiri)
        ignoreBookingWarning: true,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on BillingRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final startAt = b.startAt;

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_seat_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(child: Text("Buka Meja dari Booking", style: AppText.title)),
                  IconButton(
                    tooltip: "Tutup",
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              _infoRow("Member", "${b.customerName} (${b.customerPhone})"),
              _infoRow("Room", b.roomLabel),
              _infoRow(
                "Jadwal",
                startAt == null
                    ? "-"
                    : "${formatDate(startAt)} ${formatTime(startAt)} · ${b.durationHours} jam",
              ),
              const SizedBox(height: AppSizes.md),
              if (startAt == null)
                Text(
                  "Format jadwal booking tidak valid, tidak bisa dibuka otomatis.",
                  style: AppText.caption.copyWith(color: AppColors.danger),
                )
              else
                _buildTablePicker(),
              if (_submitError != null) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  _submitError!,
                  style: AppText.caption.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: AppSizes.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text("BATAL"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed:
                          (_selectedTable != null && startAt != null && !_submitting)
                          ? _confirm
                          : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("BUKA MEJA"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTablePicker() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_loadError!, style: AppText.caption.copyWith(color: AppColors.danger)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _load, child: const Text("Coba Lagi")),
        ],
      );
    }
    if (_freeTables.isEmpty) {
      return Text(
        "Tidak ada meja kosong di kategori \"${widget.booking.categoryName}\" saat ini.",
        style: AppText.caption.copyWith(color: AppColors.danger),
      );
    }

    return DropdownButtonFormField<PoolTable>(
      initialValue: _selectedTable,
      isExpanded: true,
      style: AppText.body,
      decoration: const InputDecoration(labelText: "Pilih Meja", isDense: true),
      items: [
        for (final t in _freeTables)
          DropdownMenuItem(value: t, child: Text(t.name)),
      ],
      onChanged: (v) => setState(() => _selectedTable = v),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: AppText.caption)),
          Expanded(
            child: Text(value, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

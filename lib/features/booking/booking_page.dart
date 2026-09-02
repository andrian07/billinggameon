import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/formatters.dart';
import '../../models/booking_request.dart';
import '../../services/booking_watcher.dart';
import '../../services/session_storage.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/booking_repository.dart';
import 'widgets/serve_booking_dialog.dart';

/// Cashier view of booking room requests coming in from the gameon member
/// app. Read-only: saldo is already deducted on gameon when the member
/// books, so there is nothing to approve here - the page just needs to show
/// new rows as they arrive, which it does by re-polling every 5 seconds.
class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  static const _refreshInterval = Duration(seconds: 5);

  final _repository = BookingRepository();

  static const _branchNames = {1: "Danau Sentarum", 2: "P.Aim"};

  List<BookingRequest> _bookings = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  int _branch = 1;

  /// null = tampilkan SEMUA booking (tidak difilter tanggal). Default: semua.
  DateTime? _filterDate;

  /// Tab aktif: false = "Belum Lewat" (booking yang jamnya belum habis),
  /// true = "Sudah Lewat" (slot booking sudah lewat total, lihat isExpired).
  bool _showExpired = false;

  final Set<int> _serving = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _branch = await SessionStorage().getBranch();
    if (!mounted) return;
    setState(() {});
    await _load();
    _timer = Timer.periodic(_refreshInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// [silent] keeps the current list on screen (no full-screen spinner) -
  /// used by the 5-second auto-refresh so the table doesn't flicker.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final bookings = await _repository.getBookings(branch: _branch);
      // urut yang paling cepat main duluan - booking tanpa jadwal valid (jarang,
      // format aneh dari gameon) ditaruh paling belakang alih-alih bikin sort error
      bookings.sort((a, b) {
        final da = a.startAt;
        final db = b.startAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
        _error = null;
      });
      // What's on screen has now been seen by a cashier - clear the badge.
      await _repository.markNotificationRead();
      BookingWatcher.instance.refreshNow();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e.toString();
      });
    }
  }

  /// Booking setelah difilter tanggal saja (belum dipisah per tab lewat/belum).
  List<BookingRequest> get _dateFilteredBookings {
    final date = _filterDate;
    if (date == null) return _bookings; // "Semua"
    return _bookings.where((b) {
      final at = b.startAt;
      return at != null &&
          at.year == date.year &&
          at.month == date.month &&
          at.day == date.day;
    }).toList();
  }

  /// Yang benar-benar ditampilkan: hasil filter tanggal, lalu dipisah sesuai
  /// tab aktif (Belum Lewat / Sudah Lewat).
  List<BookingRequest> get _visibleBookings =>
      _dateFilteredBookings.where((b) => b.isExpired == _showExpired).toList();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _filterDate = picked);
  }

  Future<void> _openServeDialog(BookingRequest booking) async {
    if (_serving.contains(booking.bookingRequestId)) return;

    // jamnya belum sampai -> belum boleh buka meja, cukup kasih tahu kasir
    final startAt = booking.startAt;
    if (startAt != null && DateTime.now().isBefore(startAt)) {
      await _showNotYetDialog(booking, startAt);
      return;
    }

    final opened = await showDialog<bool>(
      context: context,
      builder: (_) => ServeBookingDialog(booking: booking),
    );
    if (opened != true) return;

    setState(() => _serving.add(booking.bookingRequestId));
    try {
      // tandai booking selesai di gameon - meja sudah dibuka, kalau ini gagal
      // (mis. jaringan) tidak masalah besar, cuma booking-nya masih kelihatan
      // di daftar sampai berhasil ditandai lain kali / dibersihkan manual
      await _repository.confirmBooking(booking.bookingRequestId);
    } catch (e) {
      // diamkan - meja sudah kadung terbuka, jangan blokir kasir gara-gara ini
    }
    if (!mounted) return;
    AppToast.success(
      context,
      "Meja untuk booking ${booking.customerName} berhasil dibuka",
    );
    setState(() => _serving.remove(booking.bookingRequestId));
    await _load(silent: true);
  }

  Future<void> _showNotYetDialog(BookingRequest booking, DateTime startAt) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Text("Belum waktunya", style: AppText.title),
          ],
        ),
        content: Text(
          "Booking ${booking.customerName} baru mulai "
          "${formatDate(startAt)} jam ${formatTime(startAt)}.\n"
          "Meja belum bisa dibuka sebelum jam mulainya.",
          style: AppText.bodySecondary,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("Mengerti"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Booking Room",
      subtitle:
          "Booking masuk cabang ${_branchNames[_branch] ?? 'Cabang $_branch'}",
      showSearch: false,
      activeMenuKey: "booking",
      onMenuSelect: (key) => navigateToMenu(context, key),
      onRefresh: () => _load(),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildDateFilter(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _buildTabs(),
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (!_loading && _error == null && _visibleBookings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 14, 36, 6),
              child: _BookingRow.header(),
            ),
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
            Icons.event_seat_rounded,
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
              "Daftar Booking",
              style: AppText.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _loading || _error != null
                  ? "Memuat data..."
                  : "${_visibleBookings.length} booking · auto-refresh 3 detik",
              style: AppText.caption,
            ),
          ],
        ),
        const Spacer(),
        _buildSyncStatus(),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () {
            BookingWatcher.instance.refreshNow();
            AppToast.success(context, "Menyinkronkan data booking...");
          },
          icon: const Icon(Icons.sync_rounded, size: 16),
          label: const Text("Sinkronkan"),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: .5)),
          ),
        ),
      ],
    );
  }

  /// "Sinkron: Xs lalu" - jadi merah kalau data booking sudah lama tidak
  /// terbarui (server pusat kemungkinan tidak terhubung).
  Widget _buildSyncStatus() {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: BookingWatcher.instance.lastSyncAt,
      builder: (context, at, _) {
        final secs = at == null ? null : DateTime.now().difference(at).inSeconds;
        final stale = secs == null || secs > 20;
        final text = at == null
            ? "Belum tersinkron"
            : secs! < 5
            ? "Sinkron: baru saja"
            : secs < 60
            ? "Sinkron: ${secs}s lalu"
            : "Sinkron: ${secs ~/ 60}m lalu";
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              stale ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
              size: 15,
              color: stale ? AppColors.danger : AppColors.success,
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: AppText.caption.copyWith(
                color: stale ? AppColors.danger : AppColors.textSecondary,
                fontWeight: stale ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabs() {
    final all = _dateFilteredBookings;
    final upcoming = all.where((b) => !b.isExpired).length;
    final past = all.length - upcoming;
    return Row(
      children: [
        Expanded(
          child: _tab(
            label: "Belum Lewat",
            count: upcoming,
            active: !_showExpired,
            onTap: () => setState(() => _showExpired = false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _tab(
            label: "Sudah Lewat",
            count: past,
            active: _showExpired,
            onTap: () => setState(() => _showExpired = true),
          ),
        ),
      ],
    );
  }

  Widget _tab({
    required String label,
    required int count,
    required bool active,
    required VoidCallback onTap,
  }) {
    final fg = active ? Colors.white : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: .25)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$count",
                style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    final date = _filterDate;
    return Row(
      children: [
        _filterChip(
          label: "Semua",
          active: date == null,
          onTap: () => setState(() => _filterDate = null),
        ),
        const SizedBox(width: 8),
        _filterChip(
          label: date == null ? "Pilih Tanggal" : formatDate(date),
          active: date != null,
          icon: Icons.calendar_today_rounded,
          onTap: _pickDate,
        ),
        if (date != null && !_isToday(date)) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _filterDate = DateTime.now()),
            child: const Text("Hari Ini"),
          ),
        ],
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
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
    final visible = _visibleBookings;
    if (visible.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final booking = visible[index];
        final expired = booking.isExpired;
        return _RowCard(
          dimmed: expired,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _BookingRow.data(
              no: index + 1,
              booking: booking,
              serving: _serving.contains(booking.bookingRequestId),
              expired: expired,
              onServe: expired ? null : () => _openServeDialog(booking),
            ),
          ),
        );
      },
    );
  }

  String _emptyStateMessage() {
    final scope = _showExpired ? "yang sudah lewat" : "yang belum lewat";
    if (_filterDate == null) return "Belum ada booking $scope";
    return "Tidak ada booking $scope di tanggal ${formatDate(_filterDate!)}";
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
              Icons.event_seat_outlined,
              size: 30,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _emptyStateMessage(),
            textAlign: TextAlign.center,
            style: AppText.bodySecondary,
          ),
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
            onPressed: () => _load(),
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
}

/// Individual row rendered as its own card, with a hover "lift" effect -
/// same pattern as CustomerPage's _RowCard.
class _RowCard extends StatefulWidget {
  final Widget child;

  /// Baris booking yang jamnya sudah lewat: ditampilkan redup dan tanpa
  /// efek hover, supaya jelas tidak bisa ditindaklanjuti lagi.
  final bool dimmed;

  const _RowCard({required this.child, this.dimmed = false});

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered && !widget.dimmed;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: hovered
              ? AppColors.hover
              : AppColors.background.withValues(alpha: widget.dimmed ? .2 : .4),
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: hovered
                ? AppColors.primary.withValues(alpha: .4)
                : AppColors.border,
          ),
        ),
        child: Opacity(
          opacity: widget.dimmed ? .5 : 1,
          child: widget.child,
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final bool header;
  final int? no;
  final BookingRequest? booking;
  final bool serving;

  /// Jam booking sudah lewat — tombol "Buka Meja" dinonaktifkan.
  final bool expired;
  final VoidCallback? onServe;

  const _BookingRow.header()
    : header = true,
      no = null,
      booking = null,
      serving = false,
      expired = false,
      onServe = null;

  const _BookingRow.data({
    required this.no,
    required this.booking,
    this.serving = false,
    this.expired = false,
    this.onServe,
  }) : header = false;

  @override
  Widget build(BuildContext context) {
    if (header) {
      return _row(
        no: _headerText("NO"),
        name: _headerText("MEMBER"),
        phone: _headerText("TELEPON"),
        category: _headerText("ROOM / KURSI"),
        date: _headerText("TANGGAL"),
        time: _headerText("JAM"),
        duration: _headerText("DURASI", alignEnd: true),
        price: _headerText("HARGA", alignEnd: true),
        createdAt: _headerText("DIBUAT"),
        aksi: _headerText("AKSI", alignEnd: true),
      );
    }

    final b = booking!;
    final cellStyle = AppText.caption.copyWith(fontSize: 13);

    return _row(
      no: Text("$no", style: cellStyle.copyWith(color: AppColors.textHint)),
      name: Text(
        b.customerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: cellStyle.copyWith(fontWeight: FontWeight.w600),
      ),
      phone: Text(
        b.customerPhone.isNotEmpty ? b.customerPhone : "-",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: cellStyle,
      ),
      category: Text(
        b.roomLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: cellStyle.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primaryLight,
        ),
      ),
      date: Text(b.bookingDate, style: cellStyle),
      time: Text(_shortTime(b.bookingTime), style: cellStyle),
      duration: Text(
        "${b.durationHours} jam",
        textAlign: TextAlign.end,
        style: cellStyle,
      ),
      price: Text(
        formatCurrency(b.price),
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: cellStyle.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      createdAt: Text(
        b.createdAt == null
            ? "-"
            : "${formatDate(b.createdAt!)} ${formatTime(b.createdAt!)}",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: cellStyle.copyWith(color: AppColors.textSecondary),
      ),
      aksi: Align(
        alignment: Alignment.centerRight,
        child: serving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Tooltip(
                message: expired
                    ? "Jam booking sudah lewat"
                    : "Buka meja untuk booking ini",
                child: OutlinedButton.icon(
                  onPressed: onServe,
                  icon: const Icon(Icons.meeting_room_outlined, size: 15),
                  label: Text(expired ? "Kadaluarsa" : "Buka Meja"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: .5),
                    ),
                    disabledForegroundColor: AppColors.textHint,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    textStyle: AppText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  static String _shortTime(String value) {
    // "15:00:00" -> "15:00"
    final parts = value.split(':');
    if (parts.length >= 2) return "${parts[0]}:${parts[1]}";
    return value;
  }

  static Widget _headerText(String text, {bool alignEnd = false}) {
    return Text(
      text,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: AppText.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: AppColors.textSecondary,
      ),
    );
  }

  static Widget _row({
    required Widget no,
    required Widget name,
    required Widget phone,
    required Widget category,
    required Widget date,
    required Widget time,
    required Widget duration,
    required Widget price,
    required Widget createdAt,
    required Widget aksi,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 28, child: no),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: name),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: phone),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: category),
        const SizedBox(width: 10),
        SizedBox(width: 96, child: date),
        const SizedBox(width: 10),
        SizedBox(width: 52, child: time),
        const SizedBox(width: 10),
        SizedBox(width: 64, child: duration),
        const SizedBox(width: 10),
        SizedBox(width: 110, child: price),
        const SizedBox(width: 10),
        SizedBox(width: 110, child: createdAt),
        const SizedBox(width: 10),
        SizedBox(width: 110, child: aksi),
      ],
    );
  }
}

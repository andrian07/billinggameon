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
import 'data/booking_repository.dart';

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
          const Divider(height: 1, color: AppColors.divider),
          if (!_loading && _error == null && _bookings.isNotEmpty)
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
                  : "${_bookings.length} booking · auto-refresh 5 detik",
              style: AppText.caption,
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState(_error!);
    }
    if (_bookings.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _RowCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _BookingRow.data(no: index + 1, booking: _bookings[index]),
          ),
        );
      },
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
              Icons.event_seat_outlined,
              size: 30,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 14),
          Text("Belum ada booking masuk", style: AppText.bodySecondary),
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

class _BookingRow extends StatelessWidget {
  final bool header;
  final int? no;
  final BookingRequest? booking;

  const _BookingRow.header() : header = true, no = null, booking = null;

  const _BookingRow.data({required this.no, required this.booking})
    : header = false;

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
        SizedBox(width: 128, child: createdAt),
      ],
    );
  }
}

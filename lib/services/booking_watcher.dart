import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, kIsWeb;
import 'package:local_notifier/local_notifier.dart';

import '../features/booking/data/booking_repository.dart';
import '../models/booking_request.dart';
import 'session_storage.dart';

/// Polls billing_api for member self-service booking room requests in the
/// background and fires a desktop notification for each genuinely new one -
/// regardless of which page is currently open.
///
/// Same lifecycle as [TimerExpiryWatcher] / [TopupWatcher]: a singleton
/// started once from [AppLayout] (idempotent) and stopped on logout, so it
/// keeps running across every page for as long as the user is logged in.
///
/// Polls every 5 seconds (faster than TopupWatcher's 12s) - bookings are
/// time-sensitive room reservations the cashier needs to prep for quickly.
class BookingWatcher {
  BookingWatcher._();

  static final instance = BookingWatcher._();

  static const _pollInterval = Duration(seconds: 5);

  final _repository = BookingRepository();

  Timer? _timer;
  bool _checking = false;
  bool _notifierReady = false;

  final _unreadCount = ValueNotifier<int>(0);
  ValueListenable<int> get unreadCount => _unreadCount;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(_pollInterval, (_) => _check());
    _check(); // also fetch right away, don't wait for the first tick
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _unreadCount.value = 0;
  }

  /// Re-checks immediately instead of waiting for the next scheduled tick -
  /// called right after the cashier views the booking page so the header
  /// badge doesn't lag behind.
  void refreshNow() => _check();

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;

    try {
      final branch = await SessionStorage().getBranch();

      // getBookings() also does the customer auto-sync + notification logging
      // server-side (see Master::bookings() in billing_api) - this call is
      // what makes both of those happen; the list read below just reflects
      // what it already logged. Scoped to this terminal's own branch.
      await _repository.getBookings(branch: branch);

      final unread = await _repository.getNotifications(
        branch: branch,
        unreadOnly: true,
      );
      _unreadCount.value = unread.length;

      for (final item in unread) {
        await _notify(item);
      }
    } catch (_) {
      // Offline/server hiccup - try again on the next tick.
    } finally {
      _checking = false;
    }
  }

  Future<void> _notify(BookingNotificationItem item) async {
    // Desktop-only (Windows/macOS/Linux) - local_notifier has no mobile
    // support, and this app only ships as a desktop cashier terminal.
    if (kIsWeb ||
        !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return;
    }

    if (!_notifierReady) {
      await localNotifier.setup(appName: "GameOn Kasir");
      _notifierReady = true;
    }

    final notification = LocalNotification(
      title: "Booking Room Baru",
      body:
          "${item.customerName} booking ${item.categoryName} "
          "${item.bookingDate} ${item.bookingTime} (${item.durationHours} jam).",
    );
    await notification.show();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, kIsWeb;
import 'package:local_notifier/local_notifier.dart';

import '../features/topup/data/topup_repository.dart';
import '../models/topup_request.dart';

/// Polls billing_api for member self-service top up requests in the
/// background and fires a desktop notification for each genuinely new one -
/// regardless of which page is currently open.
///
/// Same lifecycle as [TimerExpiryWatcher] (see timer_expiry_watcher.dart):
/// a singleton started once from [AppLayout] (idempotent - every page
/// mounting it just no-ops after the first) and stopped on logout, so it
/// keeps running across every page for as long as the user is logged in.
class TopupWatcher {
  TopupWatcher._();

  static final instance = TopupWatcher._();

  static const _pollInterval = Duration(seconds: 12);

  final _repository = TopupRepository();

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
  /// called right after the cashier approves/reads a request so the header
  /// badge doesn't lag behind an action just taken in this same session.
  void refreshNow() => _check();

  Future<void> _check() async {
    // A slow response must not pile up overlapping requests.
    if (_checking) return;
    _checking = true;

    try {
      // pending_topups() also does the customer auto-sync + notification
      // logging server-side (see Master::pending_topups() in billing_api) -
      // this call is what makes both of those actually happen, the
      // notification list read below just reflects what it already logged.
      await _repository.getPendingTopups();

      final unread = await _repository.getNotifications(unreadOnly: true);
      _unreadCount.value = unread.length;

      for (final item in unread) {
        await _notify(item);
      }
    } catch (_) {
      // Offline/server hiccup - try again on the next tick, keep showing
      // whatever the badge already had.
    } finally {
      _checking = false;
    }
  }

  Future<void> _notify(TopupNotificationItem item) async {
    // Desktop-only (Windows/macOS/Linux) - local_notifier has no Android/iOS
    // support, and this app only ships as a desktop cashier terminal.
    if (kIsWeb || !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return;
    }

    if (!_notifierReady) {
      await localNotifier.setup(appName: "GameOn Kasir");
      _notifierReady = true;
    }

    final notification = LocalNotification(
      title: "Permintaan Top Up Baru",
      body: "${item.customerName} mengajukan top up Rp${item.amount} (${item.paymentMethod}).",
    );
    await notification.show();
  }
}

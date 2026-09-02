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
/// Polls every 3 seconds - bookings are time-sensitive room reservations the
/// cashier needs to prep for quickly, dan setiap poll sekalian menyegarkan
/// mirror booking lokal di billing_api (dipakai untuk cek bentrok saat buka
/// meja). [lastSyncAt] menandai kapan terakhir berhasil menarik data.
class BookingWatcher {
  BookingWatcher._();

  static final instance = BookingWatcher._();

  static const _pollInterval = Duration(seconds: 3);

  final _repository = BookingRepository();

  Timer? _timer;
  bool _checking = false;
  bool _notifierReady = false;

  /// booking_notification_id yang sudah pernah memunculkan notifikasi OS di
  /// sesi ini - supaya 1 booking hanya "ding" sekali, bukan tiap poll
  /// selama masih belum dibaca. Di-reset saat logout ([stop]).
  final Set<int> _notifiedIds = <int>{};

  final _unreadCount = ValueNotifier<int>(0);
  ValueListenable<int> get unreadCount => _unreadCount;

  /// Waktu (device) terakhir kali data booking berhasil ditarik dari server.
  /// null = belum pernah berhasil sejak app dibuka / login. Halaman Booking
  /// memakainya untuk menampilkan "terakhir sinkron X detik lalu".
  final _lastSyncAt = ValueNotifier<DateTime?>(null);
  ValueListenable<DateTime?> get lastSyncAt => _lastSyncAt;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(_pollInterval, (_) => _check());
    _check(); // also fetch right away, don't wait for the first tick
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _unreadCount.value = 0;
    _notifiedIds.clear();
    _lastSyncAt.value = null;
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

      // getBookings() = daftar booking yang MASIH perlu ditindaklanjuti (status
      // 'Booked' di gameon; hilang begitu kasir buka mejanya lewat
      // confirm_booking). Sekalian memicu customer auto-sync + logging
      // notifikasi di server. Proxy ke gameon, jadi bisa gagal sendiri.
      List<BookingRequest>? bookings;
      try {
        bookings = await _repository.getBookings(branch: branch);
      } catch (_) {
        // sync hiccup - biarkan badge apa adanya, coba lagi tick berikutnya
      }

      if (bookings != null) {
        // badge = booking yang belum di-acc DAN masih bisa ditindaklanjuti
        // (yang jamnya sudah lewat total tidak dihitung - lihat isExpired)
        _unreadCount.value = bookings.where((b) => !b.isExpired).length;
        _lastSyncAt.value = DateTime.now();
      }

      // Notifikasi OS: sekali per booking baru yang belum dibaca sesi ini.
      // Tetap pakai tabel booking_notification supaya "ding"-nya berhenti
      // setelah kasir membuka halaman Booking (mark-all-read).
      try {
        final unread = await _repository.getNotifications(
          branch: branch,
          unreadOnly: true,
        );
        final stillUnread = unread.map((i) => i.id).toSet();
        _notifiedIds.removeWhere((id) => !stillUnread.contains(id));
        for (final item in unread) {
          if (_notifiedIds.add(item.id)) {
            await _notify(item);
          }
        }
      } catch (_) {
        // billing_api lokal hiccup - lewati notifikasi OS untuk tick ini
      }
    } catch (_) {
      // gagal ambil branch dsb - coba lagi tick berikutnya
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

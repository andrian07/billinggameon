import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/sync/data/sync_repository.dart';

/// Keeps `history_hit_api_logs` (gameon push-failure log, see
/// migration_upload_status.sql) from growing forever - clears it every 3
/// days via `Sync::clear_api_logs()`.
///
/// The app isn't guaranteed to stay running for 3 full days straight (it's
/// a desktop cashier app, typically closed overnight), so a single
/// `Timer.periodic(Duration(days: 3))` would rarely fire. Instead the last
/// cleanup time is persisted (survives restarts) and checked on a short
/// recurring tick - same lifecycle pattern as the other watchers (singleton
/// started once from AppLayout, stopped on logout).
class ApiLogsCleanupWatcher {
  ApiLogsCleanupWatcher._();

  static final instance = ApiLogsCleanupWatcher._();

  static const _checkInterval = Duration(hours: 1);
  static const _cleanupEvery = Duration(days: 3);
  static const _prefsKey = "api_logs_last_cleanup_at";

  final _repository = SyncRepository();

  Timer? _timer;
  bool _checking = false;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(_checkInterval, (_) => _check());
    _check();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRaw = prefs.getString(_prefsKey);
      final last = lastRaw != null ? DateTime.tryParse(lastRaw) : null;

      // Belum pernah dibersihkan (instalasi baru) - catat baseline sekarang
      // saja, jangan langsung bersihkan, supaya log yang baru dibuat sebelum
      // 3 hari pertama berlalu tidak ikut kehapus.
      if (last == null) {
        await prefs.setString(_prefsKey, DateTime.now().toIso8601String());
        return;
      }

      if (DateTime.now().difference(last) < _cleanupEvery) return;

      await _repository.clearApiLogs();
      await prefs.setString(_prefsKey, DateTime.now().toIso8601String());
    } catch (_) {
      // gameon/billing_api hiccup - dibiarkan, dicoba lagi tick berikutnya.
    } finally {
      _checking = false;
    }
  }
}

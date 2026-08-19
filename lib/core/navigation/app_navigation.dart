import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/session_storage.dart';
import '../../services/timer_expiry_watcher.dart';

const _routesByKey = {
  'meja': '/meja',
  'pos': '/pos',
  'transaksi': '/transaksi',
  'pengguna': '/pengguna',
  'role': '/role',
  'pelanggan': '/pelanggan',
  'pengaturan': '/pengaturan',
  'promo': '/promo',
  'produk': '/produk',
  'pembelian': '/pembelian',
  'laporan_billing': '/laporan/billing',
  'laporan_cafe': '/laporan/cafe',
  'laporan_saldo': '/laporan/saldo',
  'laporan_stok': '/laporan/stok',
  'unit': '/unit',
  'kategori': '/kategori',
  'setting_table': '/setting/table',
  'setting_point_exchange': '/setting/point-exchange',
};

Future<void> navigateToMenu(BuildContext context, String key) async {
  if (key == 'logout') {
    TimerExpiryWatcher.instance.stop();
    await SessionStorage().clearSession();
    if (context.mounted) context.go('/login');
    return;
  }

  final route = _routesByKey[key];
  if (route == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Fitur ini akan segera hadir")),
    );
    return;
  }

  context.go(route);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../features/settings/data/pin_repository.dart';

/// Guard dipanggil sebelum tindakan destruktif (batal meja, cancel transaksi
/// cafe, hapus keep transaction). Kalau PIN keamanan tidak aktif, langsung
/// lolos tanpa dialog apa pun. Kalau aktif, munculkan dialog input PIN dan
/// verifikasi ke server; mengembalikan true hanya kalau PIN benar atau PIN
/// memang tidak aktif.
class PinGuard {
  static final PinRepository _repository = PinRepository();

  static Future<bool> confirm(BuildContext context) async {
    PinStatus status;
    try {
      status = await _repository.getStatus();
    } catch (_) {
      // Kalau status gagal diambil (mis. koneksi bermasalah), jangan blokir
      // pengguna dari tindakan yang mereka minta - fail-open, sama seperti
      // perilaku default sebelum fitur PIN ini ada.
      return true;
    }

    if (!status.active) return true;
    if (!context.mounted) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const _PinEntryDialog(),
        ) ??
        false;
  }
}

class _PinEntryDialog extends StatefulWidget {
  const _PinEntryDialog();

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  final _controller = TextEditingController();
  final _repository = PinRepository();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = "PIN wajib diisi");
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });

    final ok = await _repository.verify(pin);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _checking = false;
        _error = "PIN salah";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      title: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Text("Masukkan PIN", style: AppText.title),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tindakan ini memerlukan PIN keamanan.",
              style: AppText.bodySecondary,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              style: AppText.body,
              onSubmitted: (_) => _checking ? null : _submit(),
              decoration: InputDecoration(
                counterText: "",
                errorText: _error,
                filled: true,
                fillColor: AppColors.background,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text("BATAL"),
        ),
        ElevatedButton(
          onPressed: _checking ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text("KONFIRMASI"),
        ),
      ],
    );
  }
}

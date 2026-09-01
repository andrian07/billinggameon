import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../services/session_storage.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/pin_repository.dart';

/// Sub-menu "PIN" di bawah Ganti Password - HANYA muncul untuk owner (lihat
/// pengecekan isSuperadmin() di ChangePasswordPage). Owner mengatur PIN
/// keamanan global (bukan per-user) yang, kalau diaktifkan, wajib
/// dimasukkan sebelum tindakan destruktif (batal meja, cancel transaksi
/// cafe, hapus keep transaction) - lihat PinGuard di shared/widgets.
class PinSettingForm extends StatefulWidget {
  const PinSettingForm({super.key});

  @override
  State<PinSettingForm> createState() => _PinSettingFormState();
}

class _PinSettingFormState extends State<PinSettingForm> {
  final _repository = PinRepository();
  final _sessionStorage = SessionStorage();
  final _formKey = GlobalKey<FormState>();

  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = true;
  bool _savingPin = false;
  bool _togglingActive = false;
  PinStatus _status = PinStatus.empty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await _repository.getStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } on PinRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<int> _currentUserId() async {
    final session = await _sessionStorage.getSession();
    return int.tryParse(session?['id']?.toString() ?? "") ?? 0;
  }

  Future<void> _savePin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _savingPin = true);
    try {
      final userId = await _currentUserId();
      await _repository.setPin(userId: userId, pinCode: _pinController.text);
      if (!mounted) return;
      AppToast.success(context, "PIN berhasil disimpan");
      _pinController.clear();
      _confirmController.clear();
      _formKey.currentState!.reset();
      await _load();
    } on PinRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _savingPin = false);
    }
  }

  Future<void> _toggleActive(bool value) async {
    setState(() => _togglingActive = true);
    try {
      final userId = await _currentUserId();
      await _repository.setActive(userId: userId, active: value);
      if (!mounted) return;
      AppToast.success(context, value ? "PIN diaktifkan" : "PIN dinonaktifkan");
      await _load();
    } on PinRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _togglingActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
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
                Icons.pin_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "PIN Keamanan",
              style: AppText.title.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Apabila diaktifkan, PIN ini wajib dimasukkan setiap kali ada "
          "tindakan batal meja, cancel transaksi, atau hapus pesanan tertunda.",
          style: AppText.bodySecondary,
        ),
        const SizedBox(height: 20),

        _activeSwitchTile(),
        const SizedBox(height: 24),
        const Divider(color: AppColors.border),
        const SizedBox(height: 24),

        Text(
          _status.isSet ? "Ganti PIN" : "Atur PIN",
          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _label("PIN Baru (4-6 digit)"),
              const SizedBox(height: 8),
              _pinField(
                controller: _pinController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "PIN wajib diisi";
                  }
                  if (!RegExp(r'^\d{4,6}$').hasMatch(value)) {
                    return "PIN harus 4-6 digit angka";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              _label("Confirm PIN Baru"),
              const SizedBox(height: 8),
              _pinField(
                controller: _confirmController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Konfirmasi PIN wajib diisi";
                  }
                  if (value != _pinController.text) {
                    return "Konfirmasi tidak sama dengan PIN baru";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: _buildSaveButton(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activeSwitchTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          "Aktifkan PIN Keamanan",
          style: AppText.body.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _status.isSet
              ? (_status.active ? "Sedang aktif" : "Sedang nonaktif")
              : "Atur PIN terlebih dahulu di bawah sebelum mengaktifkan",
          style: AppText.caption,
        ),
        value: _status.active,
        activeThumbColor: AppColors.primary,
        onChanged: (!_status.isSet || _togglingActive)
            ? null
            : (value) => _toggleActive(value),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      style: AppText.body,
      validator: validator,
      decoration: InputDecoration(
        counterText: "",
        prefixIcon: const Icon(
          Icons.pin_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: _savingPin
              ? [AppColors.textHint, AppColors.textHint]
              : const [AppColors.primary, Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: InkWell(
          onTap: _savingPin ? null : _savePin,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_savingPin)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                const SizedBox(width: 10),
                Text(
                  _savingPin ? "MENYIMPAN..." : "SIMPAN PIN",
                  style: AppText.button.copyWith(letterSpacing: .4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

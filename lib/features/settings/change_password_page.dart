import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../services/session_storage.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/change_password_repository.dart';
import 'widgets/pin_setting_form.dart';

enum _SettingTab { password, pin }

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _repository = ChangePasswordRepository();
  final _sessionStorage = SessionStorage();
  final _formKey = GlobalKey<FormState>();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  _SettingTab _activeTab = _SettingTab.password;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final isOwner = await _sessionStorage.isSuperadmin();
    if (!mounted) return;
    setState(() => _isOwner = isOwner);
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final session = await _sessionStorage.getSession();
      final userId = int.tryParse(session?['id']?.toString() ?? "") ?? 0;
      if (userId <= 0) {
        throw const ChangePasswordRepositoryException(
          "Sesi tidak valid. Silakan login ulang.",
        );
      }

      await _repository.changePassword(
        userId: userId,
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;
      AppToast.success(context, "Password berhasil diubah");
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _formKey.currentState!.reset();
    } on ChangePasswordRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Ganti Password",
      subtitle: "Ubah password akun Anda sendiri",
      showSearch: false,
      activeMenuKey: "ganti_password",
      onMenuSelect: (key) => navigateToMenu(context, key),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 220, child: _buildSubMenu()),
          const SizedBox(width: 16),
          Expanded(
            child: AppCard(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SingleChildScrollView(
                    child: _activeTab == _SettingTab.password
                        ? _buildForm()
                        : const PinSettingForm(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubMenu() {
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _subMenuItem(
            icon: Icons.lock_reset_rounded,
            label: "Ganti Password",
            tab: _SettingTab.password,
          ),
          if (_isOwner) ...[
            const SizedBox(height: 4),
            _subMenuItem(
              icon: Icons.pin_outlined,
              label: "PIN",
              tab: _SettingTab.pin,
            ),
          ],
        ],
      ),
    );
  }

  Widget _subMenuItem({
    required IconData icon,
    required String label,
    required _SettingTab tab,
  }) {
    final selected = _activeTab == tab;
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: .12) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: InkWell(
        onTap: () => setState(() => _activeTab = tab),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
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
                  Icons.lock_reset_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Ganti Password",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _label("Password Lama"),
          const SizedBox(height: 8),
          _passwordField(
            controller: _oldPasswordController,
            obscure: _obscureOld,
            onToggleObscure: () => setState(() => _obscureOld = !_obscureOld),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Password lama wajib diisi";
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          _label("Password Baru"),
          const SizedBox(height: 8),
          _passwordField(
            controller: _newPasswordController,
            obscure: _obscureNew,
            onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Password baru wajib diisi";
              }
              if (value.length < 5) {
                return "Password baru minimal 5 karakter";
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          _label("Confirm Password Baru"),
          const SizedBox(height: 8),
          _passwordField(
            controller: _confirmPasswordController,
            obscure: _obscureConfirm,
            onToggleObscure: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Konfirmasi password baru wajib diisi";
              }
              if (value != _newPasswordController.text) {
                return "Konfirmasi tidak sama dengan password baru";
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: _buildSubmitButton(),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: AppText.body,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          onPressed: onToggleObscure,
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

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: _submitting
              ? [AppColors.textHint, AppColors.textHint]
              : const [AppColors.primary, Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: InkWell(
          onTap: _submitting ? null : _submit,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_submitting)
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
                  _submitting ? "MENYIMPAN..." : "SIMPAN PASSWORD",
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

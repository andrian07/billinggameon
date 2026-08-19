import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/app_user.dart';
import '../../../models/role.dart';
import '../../role/data/role_repository.dart';

class UserFormResult {
  final String username;
  final String password;
  final int roleId;

  const UserFormResult({
    required this.username,
    required this.password,
    required this.roleId,
  });
}

class UserFormDialog extends StatefulWidget {
  final AppUser? user;

  const UserFormDialog({super.key, this.user});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _roleRepository = RoleRepository();

  late final _usernameController = TextEditingController(
    text: widget.user?.username ?? "",
  );
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool _loadingRoles = true;
  String? _roleLoadError;
  List<Role> _roles = [];
  Role? _selectedRole;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _loadingRoles = true;
      _roleLoadError = null;
    });

    try {
      // Superadmin (role id 1) is excluded — the backend rejects assigning it
      // via add_user/edit_user, and there's no legitimate way to hand it out
      // from this form.
      final roles = (await _roleRepository.getRoles())
          .where((role) => role.id != 1)
          .toList();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _selectedRole = _matchById(roles, widget.user?.roleId) ??
            (roles.isNotEmpty ? roles.first : null);
        _loadingRoles = false;
      });
    } on RoleRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _roleLoadError = e.message;
        _loadingRoles = false;
      });
    }
  }

  Role? _matchById(List<Role> roles, int? id) {
    if (id == null) return null;
    for (final role in roles) {
      if (role.id == id) return role;
    }
    return null;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final role = _selectedRole;
    if (role == null) return;

    Navigator.of(context).pop(
      UserFormResult(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        roleId: role.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 22),

                _label("Username"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  style: AppText.body,
                  decoration: _inputDecoration(
                    hint: "Masukkan username",
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? "Username wajib diisi"
                      : null,
                ),

                const SizedBox(height: 20),
                _label("Password"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: AppText.body,
                  decoration:
                      _inputDecoration(
                        hint: _isEdit
                            ? "Kosongkan jika tidak ingin mengubah"
                            : "Masukkan password",
                        prefixIcon: Icons.lock_outline_rounded,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                  validator: (value) => (!_isEdit && (value == null || value.isEmpty))
                      ? "Password wajib diisi"
                      : null,
                ),

                const SizedBox(height: 20),
                _label("Role"),
                const SizedBox(height: 8),
                _buildRoleField(),

                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMedium,
                            ),
                          ),
                        ),
                        child: const Text("BATAL"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _selectedRole == null ? null : _submit,
                        icon: Icon(
                          _isEdit
                              ? Icons.save_outlined
                              : Icons.person_add_alt_1_rounded,
                          size: 20,
                        ),
                        label: Text(_isEdit ? "SIMPAN" : "TAMBAH PENGGUNA"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.textHint,
                          minimumSize: const Size(0, 48),
                          elevation: 0,
                          textStyle: AppText.button,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleField() {
    if (_loadingRoles) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_roleLoadError != null) {
      return _buildInlineError(_roleLoadError!, onRetry: _loadRoles);
    }

    if (_roles.isEmpty) {
      return _buildInlineError(
        "Belum ada role yang bisa dipilih. Tambahkan role terlebih dahulu.",
        onRetry: _loadRoles,
      );
    }

    return DropdownButtonFormField<Role>(
      initialValue: _selectedRole,
      dropdownColor: AppColors.card,
      style: AppText.body,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.textSecondary,
      ),
      decoration: _inputDecoration(prefixIcon: Icons.badge_outlined),
      items: [
        for (final role in _roles)
          DropdownMenuItem(value: role, child: Text(role.name)),
      ],
      onChanged: (value) => setState(() => _selectedRole = value ?? _selectedRole),
    );
  }

  Widget _buildInlineError(String message, {required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.danger.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text("Coba Lagi"),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.manage_accounts_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? "Edit Pengguna" : "Tambah Pengguna",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _isEdit
                    ? "Perbarui data akun pengguna"
                    : "Buat akun pengguna baru",
                style: AppText.caption,
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _inputDecoration({String? hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary)
          : null,
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    );
  }
}

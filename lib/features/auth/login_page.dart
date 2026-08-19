import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/menu_access_codes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../shared/widgets/app_button.dart';
import '../role/data/role_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _sessionStorage = SessionStorage();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      final rawId = result['user_id'];
      final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "");
      final username = result['username']?.toString();
      final role = int.tryParse(result['userrole']?.toString() ?? "");

      await _sessionStorage.saveSession({
        "id": id ?? 0,
        "username": (username != null && username.isNotEmpty)
            ? username
            : _usernameController.text.trim(),
        "role": role,
        "roleName": await _resolveRoleName(role),
      });

      await _loadAllowedMenuKeys(role);

      if (!mounted) return;
      context.go('/meja');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Looks up the display name for [role] (roles are data-driven — see
  /// [Role]) so the header can show the real role instead of a guess.
  /// Superadmin (role id 1) isn't a row in the roles table, so it's labeled
  /// directly; any lookup failure falls back to a generic label rather than
  /// blocking login.
  Future<String> _resolveRoleName(int? role) async {
    if (role == null || role == 1) return "Admin";

    try {
      final roles = await RoleRepository().getRoles();
      final match = roles.where((r) => r.id == role);
      if (match.isEmpty || match.first.name.isEmpty) return "Pengguna";
      return match.first.name;
    } catch (_) {
      return "Pengguna";
    }
  }

  /// Resolves and persists which sidebar menus [role] can view, so the
  /// sidebar can filter itself without re-fetching on every page. Role id 1
  /// is the built-in superadmin (see AppUser.isSuperadmin) and always gets
  /// unrestricted access; any other role that fails to fetch its access
  /// list also fails open rather than rendering an empty sidebar, since
  /// backend endpoints remain the real permission boundary.
  Future<void> _loadAllowedMenuKeys(int? role) async {
    if (role == null || role == 1) {
      await _sessionStorage.setAllowedMenuKeys(null);
      return;
    }

    try {
      final roleRepository = RoleRepository();
      final menus = await roleRepository.getMenus();
      final access = await roleRepository.getRoleAccess(role);

      final codeByMenuId = {for (final menu in menus) menu.id: menu.code};
      final allowedKeys = <String>{};
      for (final entry in access) {
        if (!entry.canView) continue;
        final code = codeByMenuId[entry.menuId];
        if (code == null || code.isEmpty) continue;
        allowedKeys.addAll(menuKeysForAccessCode(code));
      }

      await _sessionStorage.setAllowedMenuKeys(allowedKeys);
    } catch (_) {
      await _sessionStorage.setAllowedMenuKeys(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1220),
              AppColors.background,
              AppColors.primary,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -70,
              child: _DecorCircle(
                size: 260,
                color: AppColors.primaryLight.withValues(alpha: .18),
              ),
            ),
            Positioned(
              bottom: -110,
              right: -90,
              child: _DecorCircle(
                size: 340,
                color: AppColors.primary.withValues(alpha: .25),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 30,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("🎱 Billing", style: AppText.heading),
                          const SizedBox(height: 6),
                          Text(
                            "Sign in to manage your billiard business",
                            style: AppText.bodySecondary,
                          ),

                          const SizedBox(height: 32),

                          Text("Username", style: AppText.caption),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _usernameController,
                            style: AppText.body,
                            decoration: const InputDecoration(
                              hintText: "Enter your username",
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? "Username is required"
                                : null,
                          ),

                          const SizedBox(height: 20),

                          Text("Password", style: AppText.caption),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: AppText.body,
                            decoration: InputDecoration(
                              hintText: "Enter your password",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? "Password is required"
                                : null,
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: _errorMessage == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withValues(
                                          alpha: .12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusMedium,
                                        ),
                                        border: Border.all(
                                          color: AppColors.danger.withValues(
                                            alpha: .4,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            color: AppColors.danger,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: AppText.body.copyWith(
                                                color: AppColors.danger,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 28),

                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              title: _isLoading ? "Signing in..." : "Sign In",
                              icon: Icons.login_rounded,
                              onPressed: _isLoading ? null : _handleLogin,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

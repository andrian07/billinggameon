import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../models/app_user.dart';
import '../../models/pagination_info.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/user_repository.dart';
import 'widgets/user_form_dialog.dart';
import 'widgets/user_qr_code_dialog.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  static const _perPage = 10;

  final _repository = UserRepository();

  List<AppUser> _users = [];
  PaginationInfo _pagination = PaginationInfo.empty;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.getUsers(
        page: page,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _users = result.users;
        _pagination = result.pagination;
        _loading = false;
      });
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _goToPage(int page) {
    if (page == _pagination.currentPage || _loading) return;
    _load(page);
  }

  void _notifyError(String message) {
    AppToast.error(context, message);
  }

  void _notifySuccess(String message) {
    AppToast.success(context, message);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Text(title, style: AppText.title),
        content: Text(message, style: AppText.bodySecondary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("TIDAK"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openAddDialog() async {
    final result = await showDialog<UserFormResult>(
      context: context,
      builder: (_) => const UserFormDialog(),
    );
    if (result == null) return;

    try {
      await _repository.addUser(
        username: result.username,
        password: result.password,
        roleId: result.roleId,
      );
      if (!mounted) return;
      _notifySuccess("Pengguna ${result.username} berhasil ditambahkan");
      await _load(_pagination.currentPage);
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _notifyError(e.message);
    }
  }

  Future<void> _openEditDialog(AppUser user) async {
    final result = await showDialog<UserFormResult>(
      context: context,
      builder: (_) => UserFormDialog(user: user),
    );
    if (result == null) return;

    try {
      await _repository.editUser(
        userId: user.id,
        username: result.username,
        password: result.password.isEmpty ? null : result.password,
        roleId: result.roleId,
      );
      if (!mounted) return;
      _notifySuccess("Pengguna ${result.username} berhasil diperbarui");
      await _load(_pagination.currentPage);
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _notifyError(e.message);
    }
  }

  Future<void> _confirmDelete(AppUser user) async {
    final confirmed = await _confirm(
      title: "Hapus Pengguna?",
      message: "Apakah Anda yakin akan menghapus user \"${user.username}\"?",
      confirmLabel: "YA, HAPUS",
    );
    if (!confirmed) return;

    try {
      await _repository.deleteUser(user.id);
      if (!mounted) return;
      _notifySuccess("Pengguna ${user.username} berhasil dihapus");
      await _load(_pagination.currentPage);
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _notifyError(e.message);
    }
  }

  Future<void> _openQrCodeDialog(AppUser user) {
    return showDialog(
      context: context,
      builder: (_) => UserQrCodeDialog(user: user),
    );
  }

  Future<void> _confirmResetPassword(AppUser user) async {
    final confirmed = await _confirm(
      title: "Reset Password?",
      message:
          "Apakah Anda yakin akan mereset password user \"${user.username}\"?",
      confirmLabel: "YA, RESET",
    );
    if (!confirmed) return;

    try {
      await _repository.resetPassword(user.id);
      if (!mounted) return;
      _notifySuccess("Password ${user.username} berhasil direset");
    } on UserRepositoryException catch (e) {
      if (!mounted) return;
      _notifyError(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Pengguna",
      subtitle: "Kelola akun supervisor dan kasir",
      showSearch: false,
      activeMenuKey: "pengguna",
      onMenuSelect: (key) => navigateToMenu(context, key),
      onRefresh: () => _load(_pagination.currentPage),
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: _buildToolbar(),
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 14, 36, 6),
              child: _UserRow.header(),
            ),
          Expanded(child: _buildBody()),
          if (!_loading && _error == null && _users.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.divider),
            Container(
              color: AppColors.background.withValues(alpha: .3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: _buildPagination(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState(_error!);
    }
    if (_users.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = _users[index];
        return _RowCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _UserRow.data(
              no:
                  (_pagination.currentPage - 1) * _pagination.perPage +
                  index +
                  1,
              user: user,
              onEdit: () => _openEditDialog(user),
              onQrCode: () => _openQrCodeDialog(user),
              onResetPassword: () => _confirmResetPassword(user),
              onDelete: () => _confirmDelete(user),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Row(
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
            Icons.manage_accounts_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Daftar Pengguna",
              style: AppText.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _loading || _error != null
                  ? "Memuat data..."
                  : "${_pagination.totalItems} pengguna terdaftar",
              style: AppText.caption,
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _openAddDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: Text(
              "Tambah Pengguna",
              style: AppText.button.copyWith(fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 30,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 14),
          Text("Tidak ada pengguna ditemukan", style: AppText.bodySecondary),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 30,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodySecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _load(_pagination.currentPage),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Coba Lagi"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final p = _pagination;
    final startItem = p.totalItems == 0
        ? 0
        : (p.currentPage - 1) * p.perPage + 1;
    final endItem = (p.currentPage * p.perPage).clamp(0, p.totalItems);

    return Row(
      children: [
        Text(
          "Menampilkan $startItem-$endItem dari ${p.totalItems} pengguna",
          style: AppText.caption,
        ),
        const Spacer(),
        _pageArrow(
          icon: Icons.chevron_left_rounded,
          onTap: p.hasPrevPage ? () => _goToPage(p.currentPage - 1) : null,
        ),
        const SizedBox(width: 6),
        ..._buildPageButtons(),
        const SizedBox(width: 6),
        _pageArrow(
          icon: Icons.chevron_right_rounded,
          onTap: p.hasNextPage ? () => _goToPage(p.currentPage + 1) : null,
        ),
      ],
    );
  }

  List<Widget> _buildPageButtons() {
    final window = _pageWindow(
      _pagination.totalPages,
      _pagination.currentPage,
    );
    final widgets = <Widget>[];

    for (var i = 0; i < window.length; i++) {
      if (i > 0 && window[i] - window[i - 1] > 1) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text("...", style: AppText.caption),
          ),
        );
      }
      widgets.add(
        _pageNumberButton(
          window[i],
          active: window[i] == _pagination.currentPage,
        ),
      );
      widgets.add(const SizedBox(width: 6));
    }

    return widgets;
  }

  List<int> _pageWindow(int totalPages, int current) {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i + 1);

    final set = <int>{1, totalPages, current};
    if (current - 1 >= 1) set.add(current - 1);
    if (current + 1 <= totalPages) set.add(current + 1);

    return set.toList()..sort();
  }

  Widget _pageNumberButton(int page, {required bool active}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: active ? null : () => _goToPage(page),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          "$page",
          style: AppText.caption.copyWith(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _pageArrow({required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textSecondary : AppColors.textHint,
        ),
      ),
    );
  }
}

/// Individual row rendered as its own card, with a hover "lift" effect.
class _RowCard extends StatefulWidget {
  final Widget child;

  const _RowCard({required this.child});

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.hover
              : AppColors.background.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: _hovered
                ? AppColors.primary.withValues(alpha: .4)
                : AppColors.border,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final bool header;
  final int? no;
  final AppUser? user;
  final VoidCallback? onEdit;
  final VoidCallback? onQrCode;
  final VoidCallback? onResetPassword;
  final VoidCallback? onDelete;

  const _UserRow.header()
    : header = true,
      no = null,
      user = null,
      onEdit = null,
      onQrCode = null,
      onResetPassword = null,
      onDelete = null;

  const _UserRow.data({
    required this.no,
    required this.user,
    required this.onEdit,
    required this.onQrCode,
    required this.onResetPassword,
    required this.onDelete,
  }) : header = false;

  @override
  Widget build(BuildContext context) {
    if (header) {
      return _row(
        no: _headerText("NO"),
        id: _headerText("ID"),
        username: _headerText("USERNAME"),
        role: _headerText("ROLE"),
        aksi: _headerText("AKSI", alignCenter: true),
      );
    }

    final u = user!;
    final cellStyle = AppText.caption.copyWith(fontSize: 13);
    final roleColor = _roleColor(u.roleId);
    final roleIcon = u.isSuperadmin
        ? Icons.shield_rounded
        : Icons.badge_rounded;

    return _row(
      no: Text("$no", style: cellStyle.copyWith(color: AppColors.textHint)),
        id: Text(
          "#${u.id}",
          style: cellStyle.copyWith(color: AppColors.textSecondary),
        ),
        username: Text(
          u.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cellStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        role: u.roleId == null
            ? Text("-", style: cellStyle.copyWith(color: AppColors.textHint))
            : Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: roleColor.withValues(alpha: .3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, size: 12, color: roleColor),
                      const SizedBox(width: 5),
                      Text(
                        u.roleName ?? "Role #${u.roleId}",
                        style: AppText.caption.copyWith(
                          fontSize: 11,
                          color: roleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        aksi: u.isSuperadmin
            ? Center(
                child: Tooltip(
                  message: "Akun superadmin terkunci",
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                ),
              )
            : Center(
                child: PopupMenuButton<String>(
                  tooltip: "Aksi",
                  color: AppColors.card,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSizes.radiusMedium,
                    ),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit?.call();
                        break;
                      case 'qr':
                        onQrCode?.call();
                        break;
                      case 'reset':
                        onResetPassword?.call();
                        break;
                      case 'delete':
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: _menuItem(Icons.edit_outlined, "Edit"),
                    ),
                    PopupMenuItem(
                      value: 'qr',
                      child: _menuItem(Icons.qr_code_2_rounded, "Lihat QR"),
                    ),
                    PopupMenuItem(
                      value: 'reset',
                      child: _menuItem(
                        Icons.lock_reset_rounded,
                        "Reset Password",
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: _menuItem(
                        Icons.delete_outline_rounded,
                        "Hapus",
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  static const _rolePalette = [
    AppColors.purple,
    AppColors.info,
    AppColors.success,
    AppColors.danger,
  ];

  /// Roles are now data-driven rather than a fixed 3-value enum, so their
  /// badge color is picked deterministically from a small palette instead
  /// of being hardcoded per role — the superadmin role (id 1) keeps a
  /// distinct color since it's the one built-in, non-editable account.
  static Color _roleColor(int? roleId) {
    if (roleId == null) return AppColors.textHint;
    if (roleId == 1) return AppColors.warning;
    return _rolePalette[roleId % _rolePalette.length];
  }

  static Widget _menuItem(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppText.body.copyWith(color: color ?? AppColors.text),
        ),
      ],
    );
  }

  static Widget _headerText(String text, {bool alignCenter = false}) {
    return Text(
      text,
      textAlign: alignCenter ? TextAlign.center : TextAlign.start,
      style: AppText.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: AppColors.textSecondary,
      ),
    );
  }

  static Widget _row({
    required Widget no,
    required Widget id,
    required Widget username,
    required Widget role,
    required Widget aksi,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 32, child: no),
        const SizedBox(width: 12),
        SizedBox(width: 56, child: id),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: username),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: role),
        const SizedBox(width: 12),
        SizedBox(width: 56, child: aksi),
      ],
    );
  }
}

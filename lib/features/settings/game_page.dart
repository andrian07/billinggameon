import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../models/game.dart';
import '../../models/pagination_info.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/game_repository.dart';
import 'widgets/game_form_dialog.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const _perPage = 10;

  final _repository = GameRepository();

  List<Game> _items = [];
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
      final result = await _repository.getGames(page: page, perPage: _perPage);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _pagination = result.pagination;
        _loading = false;
      });
    } on GameRepositoryException catch (e) {
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
    final result = await showDialog<GameFormResult>(
      context: context,
      builder: (_) => const GameFormDialog(),
    );
    if (result == null) return;

    try {
      await _repository.addGame(
        name: result.name,
        branchIds: result.branchIds,
        consoles: result.consoles,
        roomIds: result.roomIds,
        description: result.description,
        image: result.image,
      );
      if (!mounted) return;
      AppToast.success(context, "${result.name} berhasil ditambahkan");
      await _load(_pagination.currentPage);
    } on GameRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  Future<void> _openEditDialog(Game item) async {
    final result = await showDialog<GameFormResult>(
      context: context,
      builder: (_) => GameFormDialog(game: item),
    );
    if (result == null) return;

    try {
      await _repository.editGame(
        id: item.id,
        name: result.name,
        branchIds: result.branchIds,
        consoles: result.consoles,
        roomIds: result.roomIds,
        description: result.description,
        image: result.image,
      );
      if (!mounted) return;
      AppToast.success(context, "${result.name} berhasil diperbarui");
      await _load(_pagination.currentPage);
    } on GameRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  Future<void> _confirmDelete(Game item) async {
    final confirmed = await _confirm(
      title: "Hapus Game?",
      message: "Apakah Anda yakin akan menghapus game \"${item.name}\"?",
      confirmLabel: "YA, HAPUS",
    );
    if (!confirmed) return;

    try {
      await _repository.deleteGame(item.id);
      if (!mounted) return;
      AppToast.success(context, "${item.name} berhasil dihapus");
      await _load(_pagination.currentPage);
    } on GameRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Game",
      subtitle: "Kelola daftar game yang tersedia",
      showSearch: false,
      activeMenuKey: "setting_game",
      onMenuSelect: (key) => navigateToMenu(context, key),
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
          if (!_loading && _error == null && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 14, 36, 6),
              child: _GameRow.header(),
            ),
          Expanded(child: _buildBody()),
          if (!_loading && _error == null && _items.isNotEmpty) ...[
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
    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _RowCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _GameRow.data(
              no:
                  (_pagination.currentPage - 1) * _pagination.perPage +
                  index +
                  1,
              item: item,
              onEdit: () => _openEditDialog(item),
              onDelete: () => _confirmDelete(item),
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
            Icons.sports_esports_rounded,
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
              "Daftar Game",
              style: AppText.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _loading || _error != null
                  ? "Memuat data..."
                  : "${_pagination.totalItems} game",
              style: AppText.caption,
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _openAddDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              "Tambah Game",
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
              Icons.sports_esports_rounded,
              size: 30,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 14),
          Text("Belum ada game ditemukan", style: AppText.bodySecondary),
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
          "Menampilkan $startItem-$endItem dari ${p.totalItems} game",
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
    final window = _pageWindow(_pagination.totalPages, _pagination.currentPage);
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

class _GameRow extends StatelessWidget {
  final bool header;
  final int? no;
  final Game? item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _GameRow.header()
    : header = true,
      no = null,
      item = null,
      onEdit = null,
      onDelete = null;

  const _GameRow.data({
    required this.no,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  }) : header = false;

  @override
  Widget build(BuildContext context) {
    if (header) {
      return _row(
        no: _headerText("NO"),
        name: _headerText("GAME"),
        branch: _headerText("CABANG"),
        console: _headerText("CONSOLE"),
        rooms: _headerText("RUANGAN"),
        desc: _headerText("KETERANGAN"),
        aksi: _headerText("AKSI", alignCenter: true),
      );
    }

    final g = item!;
    final cellStyle = AppText.caption.copyWith(fontSize: 13);
    final rooms = g.roomNames.isEmpty ? "-" : g.roomNames.join(", ");
    final branches = g.branchNames.isEmpty ? "-" : g.branchNames.join(", ");
    final consoles = g.consoles.isEmpty ? "-" : g.consoles.join(", ");

    return _row(
      no: Text("$no", style: cellStyle.copyWith(color: AppColors.textHint)),
      name: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            child: SizedBox(
              width: 32,
              height: 32,
              child: g.imageUrl.isNotEmpty
                  ? Image.network(
                      g.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _thumbnailPlaceholder(),
                    )
                  : _thumbnailPlaceholder(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              g.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cellStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      branch: Text(
        branches,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: cellStyle,
      ),
      console: Text(
        consoles,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: cellStyle,
      ),
      rooms: Text(
        rooms,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: cellStyle.copyWith(color: AppColors.textSecondary),
      ),
      desc: Text(
        g.description.isEmpty ? "-" : g.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: cellStyle.copyWith(color: AppColors.textSecondary),
      ),
      aksi: Center(
        child: PopupMenuButton<String>(
          tooltip: "Aksi",
          color: AppColors.card,
          icon: const Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            side: const BorderSide(color: AppColors.border),
          ),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit?.call();
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

  static Widget _thumbnailPlaceholder() {
    return Container(
      color: AppColors.textHint.withValues(alpha: .12),
      alignment: Alignment.center,
      child: const Icon(
        Icons.sports_esports_outlined,
        size: 16,
        color: AppColors.textHint,
      ),
    );
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

  static Widget _headerText(
    String text, {
    bool alignEnd = false,
    bool alignCenter = false,
  }) {
    return Text(
      text,
      textAlign: alignCenter
          ? TextAlign.center
          : (alignEnd ? TextAlign.end : TextAlign.start),
      style: AppText.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: AppColors.textSecondary,
      ),
    );
  }

  static Widget _row({
    required Widget no,
    required Widget name,
    required Widget branch,
    required Widget console,
    required Widget rooms,
    required Widget desc,
    required Widget aksi,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 28, child: no),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: name),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: branch),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: console),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: rooms),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: desc),
        const SizedBox(width: 10),
        SizedBox(width: 48, child: aksi),
      ],
    );
  }
}

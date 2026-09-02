import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/game.dart';
import '../../../models/table_category.dart';
import '../data/game_repository.dart';
import '../data/table_category_repository.dart';

class GameFormResult {
  final String name;
  final List<int> branchIds;
  final List<String> consoles;
  final List<int> roomIds;
  final String description;
  final GameImageInput? image;

  const GameFormResult({
    required this.name,
    required this.branchIds,
    required this.consoles,
    required this.roomIds,
    required this.description,
    this.image,
  });
}

class GameFormDialog extends StatefulWidget {
  final Game? game;

  const GameFormDialog({super.key, this.game});

  @override
  State<GameFormDialog> createState() => _GameFormDialogState();
}

class _GameFormDialogState extends State<GameFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.game?.name ?? "",
  );
  late final _descController = TextEditingController(
    text: widget.game?.description ?? "",
  );

  late final Set<int> _selectedBranches = {...?widget.game?.branchIds};
  late final Set<String> _selectedConsoles = {...?widget.game?.consoles};
  late final Set<int> _selectedRooms = {...?widget.game?.roomIds};

  bool _showBranchError = false;
  bool _showConsoleError = false;

  PlatformFile? _pickedImage;

  final _categoryRepository = TableCategoryRepository();
  List<TableCategory> _categories = [];
  bool _loadingCategories = true;

  bool get _isEdit => widget.game != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final result = await _categoryRepository.getTableCategories(
        page: 1,
        perPage: 1000,
      );
      if (!mounted) return;
      setState(() {
        _categories = result.items.where((c) => c.active).toList();
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pickedImage = result.files.first);
  }

  void _submit() {
    final nameOk = _formKey.currentState!.validate();
    final branchOk = _selectedBranches.isNotEmpty;
    final consoleOk = _selectedConsoles.isNotEmpty;
    if (!nameOk || !branchOk || !consoleOk) {
      setState(() {
        _showBranchError = !branchOk;
        _showConsoleError = !consoleOk;
      });
      return;
    }

    final image = _pickedImage;

    Navigator.of(context).pop(
      GameFormResult(
        name: _nameController.text.trim(),
        branchIds: _selectedBranches.toList(),
        consoles: _selectedConsoles.toList(),
        roomIds: _selectedRooms.toList(),
        description: _descController.text.trim(),
        image: image != null && image.bytes != null
            ? GameImageInput(filename: image.name, bytes: image.bytes!)
            : null,
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
        width: 480,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
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

                _label("Gambar Game"),
                const SizedBox(height: 8),
                _buildImagePicker(),

                const SizedBox(height: 20),
                _label("Nama Game"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: AppText.body,
                  decoration: _inputDecoration(
                    hint: "Masukkan nama game",
                    prefixIcon: Icons.sports_esports_outlined,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? "Nama game wajib diisi"
                      : null,
                ),

                const SizedBox(height: 20),
                _label("Cabang (boleh lebih dari 1)"),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in gameBranchNames.entries)
                      _selectableChip(
                        label: entry.value,
                        active: _selectedBranches.contains(entry.key),
                        onTap: () => setState(() {
                          if (!_selectedBranches.add(entry.key)) {
                            _selectedBranches.remove(entry.key);
                          }
                          _showBranchError = false;
                        }),
                      ),
                  ],
                ),
                if (_showBranchError) _fieldError("Pilih minimal 1 cabang"),

                const SizedBox(height: 20),
                _label("Console (boleh lebih dari 1)"),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in gameConsoleOptions)
                      _selectableChip(
                        label: c,
                        active: _selectedConsoles.contains(c),
                        onTap: () => setState(() {
                          if (!_selectedConsoles.add(c)) {
                            _selectedConsoles.remove(c);
                          }
                          _showConsoleError = false;
                        }),
                      ),
                  ],
                ),
                if (_showConsoleError) _fieldError("Pilih minimal 1 console"),

                const SizedBox(height: 20),
                _label("Tersedia di Ruangan (boleh lebih dari 1)"),
                const SizedBox(height: 8),
                _buildRoomSelector(),

                const SizedBox(height: 20),
                _label("Keterangan"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: AppText.body,
                  decoration: _inputDecoration(hint: "Keterangan game"),
                ),

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
                        onPressed: _submit,
                        icon: Icon(
                          _isEdit ? Icons.save_outlined : Icons.add_rounded,
                          size: 20,
                        ),
                        label: Text(_isEdit ? "SIMPAN" : "TAMBAH GAME"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
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

  Widget _buildRoomSelector() {
    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_categories.isEmpty) {
      return Text(
        "Tidak ada kategori meja / ruangan.",
        style: AppText.caption,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in _categories)
          _selectableChip(
            label: c.name,
            active: _selectedRooms.contains(c.id),
            onTap: () => setState(() {
              if (!_selectedRooms.add(c.id)) _selectedRooms.remove(c.id);
            }),
          ),
      ],
    );
  }

  Widget _selectableChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: .15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: active ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final existingUrl = widget.game?.imageUrl ?? "";
    final hasExisting = existingUrl.isNotEmpty;

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              child: SizedBox(
                width: 44,
                height: 44,
                child: _pickedImage?.bytes != null
                    ? Image.memory(_pickedImage!.bytes!, fit: BoxFit.cover)
                    : hasExisting
                    ? Image.network(
                        existingUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _pickedImage?.name ??
                    (hasExisting
                        ? "Gambar saat ini"
                        : "Belum ada gambar (pakai default)"),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySecondary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "PILIH FILE",
              style: AppText.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.textHint.withValues(alpha: .12),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: AppColors.textHint,
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
            Icons.sports_esports_rounded,
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
                _isEdit ? "Edit Game" : "Tambah Game",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _isEdit ? "Perbarui data game" : "Buat game baru",
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

  Widget _fieldError(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: AppText.caption.copyWith(color: AppColors.danger),
      ),
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

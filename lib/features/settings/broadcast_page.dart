import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../services/session_storage.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/broadcast_repository.dart';

/// Broadcast free-text ke semua member — HANYA akun owner (ms_user.userrole == 1).
/// Menu ini tidak masuk matriks Role & Akses (lihat role_access_dialog.dart), jadi
/// hanya tampil untuk owner di sidebar; halaman ini tetap cek ulang lewat
/// [SessionStorage.isSuperadmin] supaya kunjungan lewat URL langsung ikut ditolak,
/// dan billing_api Master::broadcast_member juga menolak non-owner.
class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  final _repository = BroadcastRepository();
  final _sessionStorage = SessionStorage();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  bool? _isOwner;
  bool _sending = false;

  static const _maxMessage = 500;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    final isOwner = await _sessionStorage.isSuperadmin();
    if (!mounted) return;
    setState(() => _isOwner = isOwner);
  }

  Future<void> _send() async {
    if (_isOwner != true) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      AppToast.error(context, "Pesan tidak boleh kosong");
      return;
    }

    final session = await _sessionStorage.getSession();
    final userId = int.tryParse(session?['id']?.toString() ?? "") ?? 0;
    if (!mounted) return;
    if (userId <= 0) {
      AppToast.error(context, "Sesi tidak valid, silakan login ulang");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Text("Kirim ke Semua Member?", style: AppText.title),
          ],
        ),
        content: Text(
          "Pesan ini akan dikirim sebagai notifikasi ke SEMUA member aktif "
          "dan tidak bisa ditarik kembali.",
          style: AppText.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("KIRIM"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      final result = await _repository.sendBroadcast(
        title: _titleController.text,
        message: message,
        userId: userId,
      );
      if (!mounted) return;
      AppToast.success(context, result);
      _titleController.clear();
      _messageController.clear();
    } on BroadcastRepositoryException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Broadcast Member",
      subtitle: "Kirim notifikasi ke semua member",
      showSearch: false,
      activeMenuKey: "setting_broadcast",
      onMenuSelect: (key) => navigateToMenu(context, key),
      child: _isOwner == null
          ? const Center(child: CircularProgressIndicator())
          : (_isOwner == false ? _buildAccessDenied() : _buildForm()),
    );
  }

  Widget _buildAccessDenied() {
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
              Icons.lock_outline_rounded,
              size: 30,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Hanya akun owner yang dapat mengakses halaman ini",
            style: AppText.bodySecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return AppCard(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Broadcast ke Semua Member",
                          style: AppText.title.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Muncul sebagai notifikasi di aplikasi member.",
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _label("Judul (opsional)"),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: AppText.body,
                maxLength: 100,
                decoration: _decoration(
                  hint: "mis. Info, Promo, Pengumuman",
                  icon: Icons.title_rounded,
                ),
              ),
              const SizedBox(height: 12),

              _label("Pesan"),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                style: AppText.body,
                maxLines: 6,
                maxLength: _maxMessage,
                decoration: _decoration(
                  hint: "Tulis pesan untuk semua member...",
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _sending ? "Mengirim..." : "Kirim ke Semua Member",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
  );

  InputDecoration _decoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: AppColors.textSecondary)
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
    );
  }
}

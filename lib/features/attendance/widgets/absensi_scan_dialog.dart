import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../data/attendance_repository.dart';

class _ScanLogEntry {
  final String message;
  final bool success;
  final DateTime time;

  const _ScanLogEntry({
    required this.message,
    required this.success,
    required this.time,
  });
}

/// Absensi via an external USB/HID QR scanner — those devices act as a
/// keyboard, "typing" the scanned value (the employee's user id, per the QR
/// printed from Master/user_qrcode) into whatever field has focus and
/// finishing with Enter. So this dialog just keeps a text field focused and
/// submits on Enter, rather than driving a camera — no camera permissions
/// or preview needed, and it works with the cashier's existing hardware.
class AbsensiScanDialog extends StatefulWidget {
  const AbsensiScanDialog({super.key});

  @override
  State<AbsensiScanDialog> createState() => _AbsensiScanDialogState();
}

class _AbsensiScanDialogState extends State<AbsensiScanDialog> {
  final _repository = AttendanceRepository();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _processing = false;
  final List<_ScanLogEntry> _log = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final userId = int.tryParse(value.trim());
    _controller.clear();

    if (userId == null) {
      if (value.trim().isNotEmpty) {
        setState(() {
          _log.insert(
            0,
            _ScanLogEntry(
              message: "QR tidak valid: \"${value.trim()}\"",
              success: false,
              time: DateTime.now(),
            ),
          );
        });
      }
      _refocus();
      return;
    }

    setState(() => _processing = true);

    try {
      final result = await _repository.scanAttendance(userId);
      if (!mounted) return;
      setState(() {
        _log.insert(
          0,
          _ScanLogEntry(
            message: result.message,
            success: true,
            time: DateTime.now(),
          ),
        );
        _processing = false;
      });
    } on AttendanceRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _log.insert(
          0,
          _ScanLogEntry(message: e.message, success: false, time: DateTime.now()),
        );
        _processing = false;
      });
    }

    _refocus();
  }

  void _refocus() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
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
        width: 440,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 20),
            _buildScanField(),
            const SizedBox(height: 20),
            _buildLog(),
            const SizedBox(height: 20),
            _buildActions(),
          ],
        ),
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
            Icons.qr_code_scanner_rounded,
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
                "Absensi Karyawan",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                "Arahkan alat scanner ke QR karyawan",
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

  Widget _buildScanField() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      enabled: !_processing,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppText.body,
      decoration: InputDecoration(
        hintText: "Menunggu hasil scan...",
        hintStyle: AppText.caption,
        prefixIcon: _processing
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      ),
      onSubmitted: _processing ? null : _submit,
    );
  }

  Widget _buildLog() {
    if (_log.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: Text(
          "Belum ada scan pada sesi ini",
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _log.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _logRow(_log[index]),
      ),
    );
  }

  Widget _logRow(_ScanLogEntry entry) {
    final color = entry.success ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entry.success ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: AppText.caption.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatClock(entry.time),
            style: AppText.caption.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  String _formatClock(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(time.hour)}:${two(time.minute)}:${two(time.second)}";
  }

  Widget _buildActions() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
        ),
        child: const Text("TUTUP"),
      ),
    );
  }
}

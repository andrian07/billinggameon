import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/session_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/pool_table.dart';

/// Lets staff convert a running Reguler (open-ended) session into a Timer
/// by picking how many hours to round the elapsed time up to — e.g. already
/// running 01:35:00, round up to 2 jam leaves 00:25:00 remaining as a
/// countdown. The picked target must exceed the elapsed time, checked both
/// here (so the button disables live) and again on the backend (since time
/// keeps passing while this dialog is open).
class RoundUpDurationDialog extends StatefulWidget {
  final PoolTable table;

  const RoundUpDurationDialog({super.key, required this.table});

  @override
  State<RoundUpDurationDialog> createState() => _RoundUpDurationDialogState();
}

class _RoundUpDurationDialogState extends State<RoundUpDurationDialog> {
  late int _hours;

  Duration get _elapsed {
    final startAt = widget.table.startAt;
    if (startAt == null) return Duration.zero;
    final diff = DateTime.now().difference(startAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get _isValid => _hours * 3600 > _elapsed.inSeconds;

  @override
  void initState() {
    super.initState();
    final elapsedHours = _elapsed.inSeconds / 3600;
    _hours = elapsedHours.ceil().clamp(1, hourOptions.last);
  }

  void _submit() {
    if (!_isValid) return;
    Navigator.of(context).pop(Duration(hours: _hours));
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _elapsed;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(elapsed),
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 20),

            _label("Genapkan Menjadi"),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _hours,
              dropdownColor: AppColors.card,
              style: AppText.body,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
              decoration: _inputDecoration(),
              items: [
                for (final option in hourOptions)
                  if (option > 0)
                    DropdownMenuItem(
                      value: option,
                      child: Text("$option jam"),
                    ),
              ],
              onChanged: (selected) {
                if (selected == null) return;
                setState(() => _hours = selected);
              },
            ),

            const SizedBox(height: 12),
            if (!_isValid)
              Text(
                "Sudah berjalan ${formatDuration(elapsed)} — pilih durasi "
                "yang lebih besar dari itu.",
                style: AppText.caption.copyWith(color: AppColors.danger),
              )
            else
              Text(
                "Sisa waktu setelah digenapkan: "
                "${formatDuration(Duration(hours: _hours) - elapsed)}",
                style: AppText.caption,
              ),

            const SizedBox(height: 24),
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
                    onPressed: _isValid ? _submit : null,
                    icon: const Icon(Icons.schedule_rounded, size: 20),
                    label: const Text("GENAPKAN"),
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
    );
  }

  Widget _buildHeader(Duration elapsed) {
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
            Icons.schedule_rounded,
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
                "Genapkan Waktu",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                "Sudah berjalan: ${formatDuration(elapsed)}",
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

  InputDecoration _inputDecoration() {
    return InputDecoration(
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

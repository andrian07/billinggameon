import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

enum StatusType { ready, playing, reserved, maintenance }

class StatusBadge extends StatelessWidget {
  final StatusType status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case StatusType.ready:
        color = AppColors.info;
        text = "Ready";
        break;

      case StatusType.playing:
        color = AppColors.success;
        text = "Playing";
        break;

      case StatusType.reserved:
        color = AppColors.warning;
        text = "Reserved";
        break;

      case StatusType.maintenance:
        color = AppColors.danger;
        text = "Maintenance";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: AppText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

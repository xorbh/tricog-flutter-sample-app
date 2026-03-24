import 'package:flutter/material.dart';
import '../models/ecg_record.dart';
import '../theme/app_colors.dart';

class SeverityBadge extends StatelessWidget {
  final Severity severity;
  final bool large;

  const SeverityBadge({super.key, required this.severity, this.large = false});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (severity) {
      Severity.normal => (AppColors.normalGreen, 'Normal'),
      Severity.warning => (AppColors.warningAmber, 'Warning'),
      Severity.critical => (AppColors.criticalRed, 'Critical'),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 10,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: large ? 14 : 11,
        ),
      ),
    );
  }
}

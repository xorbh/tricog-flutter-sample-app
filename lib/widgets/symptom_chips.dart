import 'package:flutter/material.dart';

class SymptomChips extends StatelessWidget {
  final List<String> symptoms;
  final bool compact;

  const SymptomChips({super.key, required this.symptoms, this.compact = false});

  static const Map<String, IconData> symptomIcons = {
    'Chest Pain': Icons.favorite,
    'Palpitations': Icons.heart_broken,
    'Dizziness': Icons.motion_photos_on,
    'Shortness of Breath': Icons.air,
    'Fatigue': Icons.battery_2_bar,
    'Routine Check': Icons.check_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    if (symptoms.isEmpty) return const SizedBox.shrink();

    final displaySymptoms = compact && symptoms.length > 2
        ? symptoms.take(2).toList()
        : symptoms;
    final overflow = compact ? symptoms.length - 2 : 0;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...displaySymptoms.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    symptomIcons[s] ?? Icons.circle,
                    size: compact ? 12 : 14,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    s,
                    style: TextStyle(
                      fontSize: compact ? 10 : 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            )),
        if (overflow > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$overflow more',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../domain/program_progress.dart';

class ProgramStreakChip extends StatelessWidget {
  const ProgramStreakChip({required this.progress, super.key});

  final ProgramProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: progress.shieldAvailable
          ? 'Série protégée : une journée manquée est pardonnée.'
          : 'Bouclier utilisé pour cette série.',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 2),
            Text('${progress.streak} j', style: theme.textTheme.labelMedium),
            const SizedBox(width: 2),
            Icon(
              progress.shieldAvailable
                  ? Icons.shield_outlined
                  : Icons.gpp_bad_outlined,
              size: 16,
              color: progress.shieldAvailable
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

String formatProgramMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return '$hours h ${rest.toString().padLeft(2, '0')}';
}

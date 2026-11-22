import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../domain/user_level.dart';

class LevelResultScreen extends StatelessWidget {
  const LevelResultScreen({
    required this.level,
    required this.onContinue,
    super.key,
  });

  final UserLevel level;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Votre niveau estimé', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  level.label,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  level.description,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'C’est une estimation, pas un examen. Vous pourrez la '
                  'modifier à tout moment dans les réglages.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: onContinue, child: const Text('Continuer')),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.onStart, this.error, super.key});

  final VoidCallback onStart;
  final String? error;

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
                  Icons.auto_stories_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Storylingo',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Améliore ton anglais en 28 jours avec des livres adaptés.',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '7 à 10 minutes par jour. Des classiques simplifiés, '
                  'l’audio synchronisé et le vocabulaire appris en contexte.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: onStart, child: const Text('Commencer')),
      ],
    );
  }
}

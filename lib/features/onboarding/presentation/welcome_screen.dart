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
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: AppRadii.cardLargeBorder,
                      child: AspectRatio(
                        aspectRatio: 3 / 2,
                        child: Image.asset(
                          'assets/onboarding/welcome_reading.jpg',
                          fit: BoxFit.cover,
                          semanticLabel:
                              'Lecture sous un arbre, un livre géant ouvert',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Storylingo',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Améliore ton anglais en 28 jours avec des livres '
                      'adaptés.',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '7 à 10 minutes par jour. Des classiques simplifiés, '
                      'l’audio synchronisé et le vocabulaire appris en '
                      'contexte.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: onStart, child: const Text('Commencer')),
      ],
    );
  }
}

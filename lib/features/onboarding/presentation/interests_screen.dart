import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../application/onboarding_controller.dart';
import '../domain/interest.dart';

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({required this.selected, super.key});

  final Set<String> selected;

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    final completed = await ref
        .read(onboardingControllerProvider.notifier)
        .complete();
    if (!mounted) return;

    if (completed) {
      context.go('/today');
      return;
    }

    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enregistrement impossible. Réessayez.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.selected.length;
    final canContinue = count >= 2 && !_saving;
    final helper = count >= 2
        ? '$count genres sélectionnés'
        : 'Encore ${2 - count} genre${2 - count > 1 ? 's' : ''} à choisir';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Étape 3 sur 3',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qu’est-ce qui vous fait tourner les pages ?',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Choisissez au moins 2 genres pour personnaliser le choix '
                  'de votre premier livre.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final interest in Interest.values)
                        FilterChip(
                          key: ValueKey('interest-${interest.id}'),
                          label: Text(interest.label),
                          selected: widget.selected.contains(interest.id),
                          onSelected: (_) => ref
                              .read(onboardingControllerProvider.notifier)
                              .toggleInterest(interest.id),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              canContinue ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: canContinue
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                helper,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: canContinue
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: canContinue ? _continue : null,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continuer'),
        ),
      ],
    );
  }
}

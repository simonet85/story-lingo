import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../domain/level_test_question.dart';

class LevelTestScreen extends StatelessWidget {
  const LevelTestScreen({
    required this.questions,
    required this.answers,
    required this.index,
    required this.onSelect,
    required this.onNext,
    super.key,
  });

  final List<LevelTestQuestion> questions;
  final List<int?> answers;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = questions[index];
    final selected = index < answers.length ? answers[index] : null;
    final isLast = index == questions.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Étape 2 sur 3',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadii.pillBorder,
          child: LinearProgressIndicator(
            value: (index + 1) / questions.length,
            minHeight: 6,
            semanticsLabel: 'Question ${index + 1} sur ${questions.length}',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Question ${index + 1} sur ${questions.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(question.prompt, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.lg),
                for (
                  var optionIndex = 0;
                  optionIndex < question.options.length;
                  optionIndex++
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _AnswerOption(
                      index: optionIndex,
                      label: question.options[optionIndex],
                      selected: selected == optionIndex,
                      onTap: () => onSelect(optionIndex),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: selected == null ? null : onNext,
          child: Text(isLast ? 'Voir mon niveau' : 'Suivant'),
        ),
      ],
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.index,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _letters = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      key: ValueKey('answer-$index'),
      selected: selected,
      button: true,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        color: selected ? scheme.primaryContainer : null,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? scheme.primary : scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Text(
                _letters[index % _letters.length],
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(label, style: theme.textTheme.bodyLarge),
              ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
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
        Text('Étape 2 sur 3', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          value: (index + 1) / questions.length,
          semanticsLabel: 'Question ${index + 1} sur ${questions.length}',
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Question ${index + 1} sur ${questions.length}',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(question.prompt, style: theme.textTheme.titleLarge),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: OutlinedButton(
        key: ValueKey('answer-$index'),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          backgroundColor: selected ? scheme.secondaryContainer : null,
          side: BorderSide(
            color: selected ? scheme.secondary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? scheme.onSecondaryContainer : scheme.outline,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../domain/word_entry.dart';
import 'saved_words_provider.dart';
import 'word_sheet.dart';

class WordListScreen extends ConsumerWidget {
  const WordListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final saved = [...ref.watch(savedWordsProvider)]
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Ma liste de mots')),
      body: saved.isEmpty
          ? const _EmptyWordList()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.contentMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${saved.length} '
                          '${saved.length == 1 ? 'mot' : 'mots'}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final word in saved)
                          _SavedWordCard(
                            word: word,
                            onRemove: () => _remove(context, ref, word),
                            onOpen: () =>
                                showWordSheet(context, entry: word.entry),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    SavedWord word,
  ) async {
    await ref.read(savedWordsProvider.notifier).remove(word.entry.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Retiré de votre liste de mots.')),
    );
  }
}

class _SavedWordCard extends StatelessWidget {
  const _SavedWordCard({
    required this.word,
    required this.onRemove,
    required this.onOpen,
  });

  final SavedWord word;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = word.entry;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onOpen,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            child: Text(
              entry.word.substring(0, 1).toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  entry.word,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry.phonetic.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    entry.phonetic,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            entry.translationFr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            tooltip: 'Retirer de la liste',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ),
    );
  }
}

class _EmptyWordList extends StatelessWidget {
  const _EmptyWordList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Votre liste est vide',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Touchez un mot surligné pendant votre lecture pour '
                'l’ajouter ici.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

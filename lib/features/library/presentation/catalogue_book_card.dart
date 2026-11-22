import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../billing/application/book_access_provider.dart';
import '../../content/data/content_repository.dart';
import '../../content/domain/catalogue.dart';
import '../../content/presentation/content_level_badge.dart';
import '../../downloads/presentation/book_download_control.dart';
import '../../reading/presentation/reading_progress_provider.dart';

class CatalogueBookCard extends ConsumerWidget {
  const CatalogueBookCard({required this.book, super.key});

  final CatalogueBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locked =
        ref.watch(bookAccessProvider(book.id)) == BookAccess.locked;
    final manifest = ref.watch(bookManifestProvider(book.id)).value;
    final firstChapter = manifest == null || manifest.chapters.isEmpty
        ? null
        : manifest.chapters.first;
    ref.watch(readingProgressProvider);
    final reading = firstChapter == null
        ? null
        : ref
              .read(readingProgressProvider.notifier)
              .stateFor(book.id, firstChapter.id);
    final chapterLabel = book.chapterCount == 1
        ? '1 chapitre'
        : '${book.chapterCount} chapitres';
    final metadata =
        '≈ ${book.totalMinutes} min · '
        '${book.newWordCount} mots nouveaux · $chapterLabel';
    final readLabel = firstChapter == null
        ? 'Lire ce livre'
        : reading!.completed
        ? 'Relire le chapitre ${firstChapter.number}'
        : reading.hasPosition
        ? 'Continuer le chapitre ${firstChapter.number}'
        : 'Lire le chapitre ${firstChapter.number}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ContentLevelBadge(level: book.level.shortLabel),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  locked ? Icons.lock_outline : Icons.cloud_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    book.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(book.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              book.titleFr,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(book.descriptionFr, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              metadata,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (locked) {
                    context.push('/paywall?bookId=${book.id}');
                    return;
                  }
                  context.push(
                    firstChapter == null
                        ? '/read/${book.id}'
                        : '/read/${book.id}/${firstChapter.id}',
                  );
                },
                icon: Icon(locked ? Icons.lock_outline : Icons.play_arrow),
                label: Text(
                  locked ? 'Débloquer avec l’abonnement' : readLabel,
                ),
              ),
            ),
            if (!locked)
              BookDownloadControl(
                bookId: book.id,
                availableVersion: book.packVersion,
              ),
          ],
        ),
      ),
    );
  }
}

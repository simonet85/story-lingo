import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/book_cover.dart';
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
    final scheme = theme.colorScheme;
    final locked = ref.watch(bookAccessProvider(book.id)) == BookAccess.locked;
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

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                height: 88,
                child: BookCover(
                  title: book.title,
                  seed: book.id,
                  compact: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ContentLevelBadge(level: book.level.shortLabel),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          locked ? Icons.lock_outline : Icons.cloud_outlined,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      book.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.titleFr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      book.author,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            book.descriptionFr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            metadata,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.md),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    );
  }
}

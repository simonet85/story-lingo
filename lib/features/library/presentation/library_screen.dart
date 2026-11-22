import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../content/data/content_repository.dart';
import '../../content/domain/catalogue.dart';
import '../../shell/presentation/storylingo_app_bar.dart';
import 'catalogue_book_card.dart';
import 'pilot_book_card.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider);

    return Scaffold(
      appBar: const StorylingoAppBar(title: 'Bibliothèque'),
      body: switch (catalogue) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError() => _LibraryError(
          onRetry: () {
            ref.invalidate(pilotBookProvider);
            ref.invalidate(catalogueProvider);
          },
        ),
        AsyncValue(:final value?) => ListView(
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
                      'Choisissez une histoire',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (value.isOffline) ...[
                      const SizedBox(height: AppSpacing.md),
                      _CatalogueNotice(
                        source: value.source,
                        onRetry: () => ref.invalidate(catalogueProvider),
                      ),
                    ],
                    for (final book in value.books)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: book.isEmbedded
                            ? PilotBookCard(
                                manifest: value.pilot,
                                onRead: () => context.push(
                                  '/read/${value.pilot.id}/'
                                  '${value.pilot.chapters.first.id}',
                                ),
                              )
                            : CatalogueBookCard(book: book),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      },
    );
  }
}

class _CatalogueNotice extends StatelessWidget {
  const _CatalogueNotice({required this.source, required this.onRetry});

  final CatalogueSource source;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cached = source == CatalogueSource.cache;
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              cached ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                cached
                    ? 'Catalogue en cache — actualisation automatique '
                          'toutes les 12 h.'
                    : 'Catalogue indisponible — dernière version '
                          'enregistrée.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              onPressed: onRetry,
              tooltip: 'Actualiser le catalogue',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Impossible de charger la bibliothèque.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

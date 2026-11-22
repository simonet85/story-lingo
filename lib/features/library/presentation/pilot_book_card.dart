import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../content/data/content_repository.dart';
import '../../content/domain/book_manifest.dart';
import '../../content/presentation/content_level_badge.dart';
import '../../downloads/presentation/book_download_control.dart';
import '../../reading/presentation/reading_progress_provider.dart';

class PilotBookCard extends ConsumerWidget {
  const PilotBookCard({
    required this.manifest,
    required this.onRead,
    super.key,
  });

  final BookManifest manifest;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chapter = manifest.chapters.first;
    final chapterCount = manifest.chapters.length;
    final chapterLabel = chapterCount == 1
        ? '1 chapitre'
        : '$chapterCount chapitres';
    final metadata =
        '≈ ${manifest.totalEstimatedMinutes} min · '
        '${manifest.totalNewWords} mots nouveaux · $chapterLabel';
    ref.watch(readingProgressProvider);
    final reading = ref
        .read(readingProgressProvider.notifier)
        .stateFor(manifest.id, chapter.id);
    final readLabel = reading.completed
        ? 'Relire le chapitre ${chapter.number}'
        : reading.hasPosition
        ? 'Continuer le chapitre ${chapter.number}'
        : 'Lire le chapitre ${chapter.number}';
    final availableVersion =
        ref.watch(pilotBookProvider).value?.packVersion ?? manifest.packVersion;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ContentLevelBadge(level: manifest.level.shortLabel),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    manifest.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(manifest.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              manifest.titleFr,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(manifest.descriptionFr, style: theme.textTheme.bodyMedium),
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
                onPressed: onRead,
                icon: const Icon(Icons.play_arrow),
                label: Text(readLabel),
              ),
            ),
            BookDownloadControl(
              bookId: manifest.id,
              availableVersion: availableVersion,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../content/data/content_repository.dart';
import '../../content/domain/book_manifest.dart';
import '../../program/domain/program_progress.dart';
import '../../program/domain/program_schedule.dart';
import '../../program/presentation/program_provider.dart';
import '../../program/presentation/program_streak_chip.dart';
import '../../reading/domain/chapter_reading_state.dart';
import '../../reading/presentation/reading_progress_provider.dart';
import '../../shell/presentation/storylingo_app_bar.dart';
import '../../vocabulary/domain/review_queue.dart';
import '../../vocabulary/presentation/srs_provider.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(programProgressProvider);
    final book = ref.watch(pilotBookProvider);
    final queue = ref.watch(reviewQueueProvider);
    final cardCount = ref.watch(srsProvider).length;
    ref.watch(readingProgressProvider);

    final manifest = book.value;
    final chapter = manifest == null
        ? null
        : chapterForDay(manifest, progress.currentDay);
    final readingState = manifest == null || chapter == null
        ? null
        : ref
              .read(readingProgressProvider.notifier)
              .stateFor(manifest.id, chapter.id);

    return Scaffold(
      appBar: const StorylingoAppBar(title: 'Aujourd’hui'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Votre prochaine session', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Un chapitre court, puis la révision de vos mots nouveaux.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProgramCard(
            progress: progress,
            chapter: chapter,
            readingState: readingState,
            onStart: manifest == null || chapter == null
                ? null
                : () => context.push('/read/${manifest.id}/${chapter.id}'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _DailyWordsCard(queue: queue, cardCount: cardCount),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Retrouvez le livre pilote dans l’onglet Bibliothèque.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.progress,
    required this.chapter,
    required this.readingState,
    required this.onStart,
  });

  final ProgramProgress progress;
  final BookChapterSummary? chapter;
  final ChapterReadingState? readingState;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = progress.doneToday;
    final minutes = chapter == null
        ? AppSizes.coreSessionMinutes
        : chapter!.estimatedMinutes + 3;

    final header = progress.programComplete
        ? 'Parcours terminé'
        : 'Jour ${progress.currentDay} sur $programLength';
    final objective = chapter == null
        ? 'Chapitre du jour'
        : 'Chapitre ${chapter!.number} · révision de vos mots';
    final status = done
        ? 'Objectif du jour terminé'
        : progress.programComplete
        ? 'Programme accompli — entraînement libre'
        : 'À faire aujourd’hui';
    final action = _actionLabel();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(header, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: AppSpacing.sm),
                ProgramStreakChip(progress: progress),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.daysCompleted / programLength,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(objective, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '≈ $minutes min · lecture + révision',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  done ? Icons.check_circle_outline : Icons.schedule_outlined,
                  size: 18,
                  color: done
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    status,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: done
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: Icon(done ? Icons.replay_outlined : Icons.play_arrow),
                label: Text(
                  action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _actionLabel() {
    final chapterNumber = chapter?.number;
    if (chapterNumber == null) return 'Commencer la session';
    if (progress.doneToday || progress.programComplete) {
      return 'Relire le chapitre $chapterNumber';
    }
    if (readingState?.paragraphId != null) {
      return 'Reprendre le chapitre $chapterNumber';
    }
    return 'Commencer la session';
  }
}

class _DailyWordsCard extends StatelessWidget {
  const _DailyWordsCard({required this.queue, required this.cardCount});

  final ReviewQueue queue;
  final int cardCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studied = queue.newStudiedToday;
    final goal = queue.dailyNewGoal;
    final progress = goal == 0 ? 0.0 : (studied / goal).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.style_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Vos mots du jour',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nouveaux mots : $studied/$goal',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              queue.isEmpty
                  ? 'Tout est à jour.'
                  : '${queue.dueCount} '
                        '${queue.dueCount == 1 ? 'carte à réviser' : 'cartes à réviser'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (cardCount == 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Terminez un chapitre pour recevoir vos premiers mots à '
                'réviser.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: queue.isEmpty ? null : () => context.push('/review'),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Réviser mes mots'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

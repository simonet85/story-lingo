import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/activity_table.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/book_cover.dart';
import '../../../core/ui/progress_bar.dart';
import '../../../core/ui/section_header.dart';
import '../../../core/ui/stat_card.dart';
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
import 'dashboard_stats_provider.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(programProgressProvider);
    final book = ref.watch(pilotBookProvider);
    final queue = ref.watch(reviewQueueProvider);
    final cardCount = ref.watch(srsProvider).length;
    final stats = ref.watch(dashboardStatsProvider);
    final now = ref.watch(nowProvider)();
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
    final wide = MediaQuery.sizeOf(context).width >= AppSizes.wideBreakpoint;

    final sessionCard = _ProgramCard(
      progress: progress,
      book: manifest,
      chapter: chapter,
      readingState: readingState,
      onStart: manifest == null || chapter == null
          ? null
          : () => context.push('/read/${manifest.id}/${chapter.id}'),
    );
    final wordsCard = _DailyWordsCard(queue: queue, cardCount: cardCount);
    const footnote = _LibraryFootnote();

    return Scaffold(
      appBar: const StorylingoAppBar(title: 'Aujourd’hui'),
      body: ListView(
        padding: EdgeInsets.all(wide ? AppSpacing.xl : AppSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide ? 1120 : AppSizes.tabContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Votre prochaine session',
                    subtitle:
                        'Un chapitre court, puis la révision de vos mots '
                        'nouveaux.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (wide) ...[
                    _KpiRow(stats: stats),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              sessionCard,
                              const SizedBox(height: AppSpacing.lg),
                              wordsCard,
                              const SizedBox(height: AppSpacing.md),
                              footnote,
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(
                                title: 'Activité récente',
                                subtitle:
                                    'Vos derniers chapitres et révisions.',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ActivityTable(rows: stats.activity, now: now),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    sessionCard,
                    const SizedBox(height: AppSpacing.lg),
                    wordsCard,
                    const SizedBox(height: AppSpacing.md),
                    footnote,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryFootnote extends StatelessWidget {
  const _LibraryFootnote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Retrouvez le livre pilote dans l’onglet Bibliothèque.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 4 : 2;
        final gap = AppSpacing.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: StatCard(
                icon: Icons.local_fire_department_outlined,
                label: 'Série',
                value: '${stats.streak} j',
                caption: 'Jours d’affilée',
                accent: true,
              ),
            ),
            SizedBox(
              width: width,
              child: StatCard(
                icon: Icons.timer_outlined,
                label: 'Minutes sur 7 jours',
                value: formatProgramMinutes(stats.minutesLast7Days),
                caption: 'Lecture et révision',
              ),
            ),
            SizedBox(
              width: width,
              child: StatCard(
                icon: Icons.menu_book_outlined,
                label: 'Chapitres terminés',
                value: '${stats.chaptersCompleted}',
                caption: 'Depuis le début',
              ),
            ),
            SizedBox(
              width: width,
              child: StatCard(
                icon: Icons.style_outlined,
                label: 'Mots maîtrisés',
                value: '${stats.wordsMastered}',
                caption: 'Revus au moins ${AppSizes.masteredReviewCount} fois',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.progress,
    required this.book,
    required this.chapter,
    required this.readingState,
    required this.onStart,
  });

  final ProgramProgress progress;
  final BookManifest? book;
  final BookChapterSummary? chapter;
  final ChapterReadingState? readingState;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                height: 100,
                child: BookCover(
                  title: book?.title ?? 'Storylingo',
                  seed: book?.id ?? 'storylingo',
                  compact: true,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            header,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ProgramStreakChip(progress: progress),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      objective,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (chapter != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        chapter!.title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '≈ $minutes min · lecture + révision',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppProgressBar(
            value: progress.daysCompleted / programLength,
            height: 8,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_outline : Icons.schedule_outlined,
                size: 18,
                color: done ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  status,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: done ? scheme.primary : scheme.onSurfaceVariant,
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
              label: Text(action, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
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
    final scheme = theme.colorScheme;
    final studied = queue.newStudiedToday;
    final goal = queue.dailyNewGoal;
    final progress = goal == 0 ? 0.0 : (studied / goal).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.style_outlined,
                  size: 18,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Vos mots du jour',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nouveaux mots : $studied/$goal',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text(
                queue.isEmpty
                    ? 'Tout est à jour.'
                    : '${queue.dueCount} '
                          '${queue.dueCount == 1 ? 'carte à réviser' : 'cartes à réviser'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AppProgressBar(value: progress),
          if (cardCount == 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Terminez un chapitre pour recevoir vos premiers mots à '
              'réviser.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
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
    );
  }
}

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/progress_bar.dart';
import '../../../core/ui/section_header.dart';
import '../../../core/ui/stat_card.dart';
import '../../program/domain/program_badges.dart';
import '../../program/domain/program_progress.dart';
import '../../program/presentation/program_provider.dart';
import '../../program/presentation/program_streak_chip.dart';
import '../../shell/presentation/storylingo_app_bar.dart';
import '../../vocabulary/presentation/srs_provider.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(programProgressProvider);
    final cards = ref.watch(srsProvider);
    final totalReviews = cards.fold(0, (sum, card) => sum + card.reviews);
    final badges = evaluateProgramBadges(
      progress: progress,
      vocabularyCards: cards.length,
    );
    final wide = MediaQuery.sizeOf(context).width >= AppSizes.wideBreakpoint;

    return Scaffold(
      appBar: const StorylingoAppBar(title: 'Progrès'),
      body: ListView(
        padding: EdgeInsets.all(wide ? AppSpacing.xl : AppSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide ? 880 : AppSizes.tabContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProgramSummaryCard(progress: progress),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(title: 'Vos statistiques'),
                  const SizedBox(height: AppSpacing.md),
                  _StatsRow(
                    minutes: formatProgramMinutes(progress.totalMinutes),
                    words: cards.length,
                    reviews: totalReviews,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(title: 'Badges'),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 560 ? 2 : 1;
                      const gap = AppSpacing.md;
                      final width =
                          (constraints.maxWidth - gap * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final status in badges)
                            SizedBox(
                              width: width,
                              child: _BadgeTile(status: status),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramSummaryCard extends StatelessWidget {
  const _ProgramSummaryCard({required this.progress});

  final ProgramProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.programComplete
                      ? 'Parcours terminé'
                      : 'Jour ${progress.currentDay} sur $programLength',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ProgramStreakChip(progress: progress),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppProgressBar(
            value: progress.daysCompleted / programLength,
            height: 8,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${progress.daysCompleted} '
            '${progress.daysCompleted == 1 ? 'jour' : 'jours'} sur '
            '$programLength',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _Fact(
                icon: Icons.local_fire_department_outlined,
                label: 'Série : ${progress.streak} j',
              ),
              _Fact(
                icon: progress.shieldAvailable
                    ? Icons.shield_outlined
                    : Icons.gpp_bad_outlined,
                label: progress.shieldAvailable
                    ? 'Bouclier disponible'
                    : 'Bouclier utilisé',
              ),
              _Fact(
                icon: Icons.emoji_events_outlined,
                label: 'Record : ${progress.bestStreak} j',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DayGrid(progress: progress),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.progress});

  final ProgramProgress progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        final cell = math.min(40.0, (constraints.maxWidth - gap * 6) / 7);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var day = 1; day <= programLength; day++)
              _DayCell(
                day: day,
                size: cell,
                validated: day <= progress.daysCompleted,
                current: day == progress.currentDay,
              ),
          ],
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.size,
    required this.validated,
    required this.current,
  });

  final int day;
  final double size;
  final bool validated;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: validated
          ? 'Jour $day validé'
          : current
          ? 'Jour $day, en cours'
          : 'Jour $day à venir',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: validated
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          border: current
              ? Border.all(color: scheme.primary, width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: validated
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: current ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.minutes,
    required this.words,
    required this.reviews,
  });

  final String minutes;
  final int words;
  final int reviews;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 1;
        const gap = AppSpacing.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: StatCard(
                icon: Icons.timer_outlined,
                label: 'Minutes lues',
                value: minutes,
              ),
            ),
            SizedBox(
              width: width,
              child: StatCard(
                icon: Icons.style_outlined,
                label: 'Mots en révision',
                value: '$words',
              ),
            ),
            SizedBox(
              width: width,
              child: StatCard(
                icon: Icons.school_outlined,
                label: 'Révisions',
                value: '$reviews',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.status});

  final ProgramBadgeStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final earned = status.earned;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: earned
          ? null
          : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconFor(status.badge),
            size: 24,
            color: earned ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.badge.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: earned ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  status.badge.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            earned ? Icons.check_circle : Icons.lock_outline,
            size: 20,
            color: earned ? scheme.primary : scheme.onSurfaceVariant,
            semanticLabel: earned ? 'Débloqué' : 'Verrouillé',
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(ProgramBadge badge) => switch (badge) {
  ProgramBadge.firstDay => Icons.flag_outlined,
  ProgramBadge.streak3 => Icons.local_fire_department_outlined,
  ProgramBadge.streak7 => Icons.calendar_view_week_outlined,
  ProgramBadge.halfway => Icons.hiking_outlined,
  ProgramBadge.complete => Icons.emoji_events_outlined,
  ProgramBadge.tenWords => Icons.style_outlined,
};

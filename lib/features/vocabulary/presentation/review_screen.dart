import 'dart:async';

import 'package:fsrs/fsrs.dart' show Rating;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../program/domain/program_progress.dart';
import '../../program/presentation/program_provider.dart';
import '../../program/presentation/program_streak_chip.dart';
import '../../telemetry/presentation/telemetry_provider.dart';
import '../domain/srs_card.dart';
import '../domain/word_entry.dart';
import '../domain/word_pronouncer.dart';
import 'pronunciation_providers.dart';
import 'srs_provider.dart';
import 'word_list_button.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final List<String> _queue = [];
  final Map<String, SrsCard> _cards = {};
  final Set<String> _reviewedIds = {};
  final Set<String> _againIds = {};
  final Map<String, int> _attempts = {};
  final Map<Rating, int> _ratings = {};

  WordPronouncer? _pronouncer;
  int _index = 0;
  bool _revealed = false;
  bool _finished = false;
  bool _rating = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    for (final card in ref.read(reviewQueueProvider).cards) {
      _queue.add(card.entry.id);
      _cards[card.entry.id] = card;
    }
    _finished = _queue.isEmpty;
    final queueSize = _queue.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(telemetryProvider.notifier)
            .record(
              'review_started',
              properties: {'queueSize': queueSize},
            ),
      );
    });
  }

  @override
  void dispose() {
    final pronouncer = _pronouncer;
    if (pronouncer != null) unawaited(pronouncer.stop());
    super.dispose();
  }

  WordPronouncer get _voice {
    final existing = _pronouncer;
    if (existing != null) return existing;
    final created = ref.read(wordPronouncerProvider);
    _pronouncer = created;
    return created;
  }

  SrsCard? get _current =>
      !_finished && _index < _queue.length ? _cards[_queue[_index]] : null;

  Future<void> _pronounce(WordEntry entry) async {
    setState(() => _notice = null);
    try {
      await _voice.pronounce(word: entry.word, clip: entry.clip);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notice = 'Prononciation indisponible.');
    }
  }

  Future<void> _rate(Rating rating) async {
    if (_rating || _finished) return;
    final id = _queue[_index];
    setState(() => _rating = true);

    await ref.read(srsProvider.notifier).rate(id, rating);
    await _voice.stop();

    if (!mounted) return;
    final attempts = (_attempts[id] ?? 0) + 1;
    _attempts[id] = attempts;
    _reviewedIds.add(id);
    _ratings.update(rating, (count) => count + 1, ifAbsent: () => 1);
    if (rating == Rating.again) {
      _againIds.add(id);
      if (attempts == 1) _queue.add(id);
    }

    setState(() {
      _rating = false;
      _index++;
      _revealed = false;
      _notice = null;
      _finished = _index >= _queue.length;
    });

    if (_finished) {
      unawaited(
        ref
            .read(telemetryProvider.notifier)
            .record(
              'review_completed',
              properties: {
                'reviewed': _reviewedIds.length,
                'again': _againIds.length,
                'hard': _ratings[Rating.hard] ?? 0,
                'good': _ratings[Rating.good] ?? 0,
                'easy': _ratings[Rating.easy] ?? 0,
                'queueSize': _queue.length,
              },
            ),
      );
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(programProgressProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Révision'),
        actions: const [WordListButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
            child: _finished
                ? _Summary(
                    reviewed: _reviewedIds.length,
                    again: _againIds.length,
                    empty: _queue.isEmpty,
                    progress: progress,
                    onLeave: _leave,
                  )
                : _buildSession(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildSession(ThemeData theme) {
    final card = _current;
    if (card == null) return const SizedBox.shrink();
    final entry = card.entry;
    final pos = partOfSpeechLabel(entry.partOfSpeech);
    final total = _queue.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Carte ${_index + 1} sur $total',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : (_index / total).clamp(0.0, 1.0),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Text(
                          entry.word,
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        if (entry.phonetic.isNotEmpty || pos.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (entry.phonetic.isNotEmpty)
                                Text(
                                  entry.phonetic,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (pos.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    pos,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSecondaryContainer,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: () => _pronounce(entry),
                          icon: const Icon(Icons.volume_up_outlined),
                          label: const Text('Écouter'),
                        ),
                        if (_notice != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _notice!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (!_revealed) ...[
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () =>
                                  setState(() => _revealed = true),
                              child: const Text('Afficher la réponse'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_revealed) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.translationFr,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (entry.definitionEn.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Définition',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              entry.definitionEn,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                          if (entry.example.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              '“${entry.example}”',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Comment était-ce ?',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _RatingRow(
                    left: _RatingButton(
                      label: 'À revoir',
                      onPressed: _rating ? null : () => _rate(Rating.again),
                    ),
                    right: _RatingButton(
                      label: 'Difficile',
                      onPressed: _rating ? null : () => _rate(Rating.hard),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _RatingRow(
                    left: _RatingButton(
                      label: 'Bien',
                      onPressed: _rating ? null : () => _rate(Rating.good),
                    ),
                    right: _RatingButton(
                      label: 'Facile',
                      onPressed: _rating ? null : () => _rate(Rating.easy),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: right),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.minTouchTarget,
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.reviewed,
    required this.again,
    required this.empty,
    required this.progress,
    required this.onLeave,
  });

  final int reviewed;
  final int again;
  final bool empty;
  final ProgramProgress progress;
  final VoidCallback onLeave;

  String get _encouragement {
    if (progress.programComplete) {
      return 'Parcours de 28 jours accompli — bravo !';
    }
    if (progress.doneToday) {
      return 'Jour ${progress.currentDay} validé. Votre série continue.';
    }
    return 'Vos mots sont à jour pour aujourd’hui.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Icon(
            empty ? Icons.nights_stay_outlined : Icons.check_circle,
            size: 64,
            color: empty
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            empty ? 'Rien à réviser pour le moment' : 'Belle session !',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            empty
                ? 'Terminez un chapitre pour ajouter ses mots à votre '
                      'révision.'
                : '$reviewed ${reviewed == 1 ? 'mot revu' : 'mots revus'}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (!empty) ...[
            if (again > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$again ${again == 1 ? 'mot à revoir' : 'mots à revoir'} '
                'bientôt.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _encouragement,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ProgramStreakChip(progress: progress),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onLeave,
              child: Text(empty ? 'Retour' : 'Terminer la session'),
            ),
          ),
        ],
      ),
    );
  }
}

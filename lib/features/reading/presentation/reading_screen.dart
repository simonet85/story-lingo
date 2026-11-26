import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/prefs/user_prefs_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/book_cover.dart';
import '../../content/data/content_repository.dart';
import '../../content/domain/book_manifest.dart';
import '../../content/domain/chapter.dart';
import '../../content/domain/chapter_dictionary.dart';
import '../../content/domain/content_offline_exception.dart';
import '../../content/presentation/content_level_badge.dart';
import '../../program/presentation/program_provider.dart';
import '../../telemetry/presentation/telemetry_provider.dart';
import '../../vocabulary/presentation/saved_words_provider.dart';
import '../../vocabulary/presentation/srs_provider.dart';
import '../../vocabulary/presentation/word_list_button.dart';
import '../../vocabulary/presentation/word_sheet.dart';
import '../domain/reading_mode.dart';
import '../domain/session_clock.dart';
import 'audio_providers.dart';
import 'audio_session_controller.dart';
import 'audio_transport.dart';
import 'chapter_paragraph_text.dart';
import 'reading_progress_provider.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({
    required this.bookId,
    required this.chapterId,
    super.key,
  });

  final String bookId;
  final String chapterId;

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen>
    with WidgetsBindingObserver {
  final Map<String, GlobalKey> _paragraphKeys = {};
  Timer? _ticker;
  SessionClock? _clock;
  Chapter? _chapter;
  ReadingMode _mode = ReadingMode.read;
  AudioSessionController? _audio;
  bool _timerStarted = false;
  bool _telemetryStarted = false;
  bool _restored = false;
  bool _restoring = false;
  bool _userScrolled = false;
  bool _completed = false;
  bool _completing = false;
  int _introducedCount = 0;
  bool _audioPlayed = false;
  bool _followAudio = false;
  bool _wasPlaying = false;
  String? _followedParagraphId;
  Duration _lastAudioPosition = Duration.zero;
  String? _lastSavedAnchor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode = ref.read(prefsRepositoryProvider).loadReadingMode();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audio?.removeListener(_onAudioChanged);
    _audio?.dispose();
    _audio = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _ensureAudio(Chapter chapter) {
    if (!chapter.hasAudio || _audio != null) return;
    final prefs = ref.read(prefsRepositoryProvider);
    _audio = AudioSessionController(
      engine: ref.read(audioEngineFactoryProvider)(),
      chapter: chapter,
      initialSpeed: prefs.loadAudioSpeed(),
      onSpeedChanged: prefs.saveAudioSpeed,
    )..addListener(_onAudioChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _audio?.ensureLoaded();
    });
  }

  void _setMode(ReadingMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _followedParagraphId = null;
      _followAudio = mode == ReadingMode.readListen;
    });
    ref.read(prefsRepositoryProvider).saveReadingMode(mode);
    final chapter = _chapter;
    if (chapter != null && mode.usesAudio) _ensureAudio(chapter);
    if (!mode.usesAudio) _audio?.pause();
  }

  void _onAudioChanged() {
    final audio = _audio;
    if (!mounted || audio == null) return;

    final seeked =
        (audio.position - _lastAudioPosition).abs() >
        const Duration(seconds: 2);
    final startedPlaying = audio.isPlaying && !_wasPlaying;
    _wasPlaying = audio.isPlaying;
    _lastAudioPosition = audio.position;
    if (audio.isPlaying) _audioPlayed = true;

    if (startedPlaying || seeked) {
      _followAudio = true;
      _followedParagraphId = null;
    }

    if (_mode == ReadingMode.readListen &&
        _followAudio &&
        (audio.isPlaying || seeked)) {
      _followActiveParagraph(audio.activeParagraphId);
    }

    if (_mode == ReadingMode.readListen) setState(() {});
  }

  void _followActiveParagraph(String? paragraphId) {
    if (paragraphId == null || paragraphId == _followedParagraphId) return;
    _followedParagraphId = paragraphId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _paragraphKeys[paragraphId]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.05,
        duration: const Duration(milliseconds: 350),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_clock == null || _completed) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _ticker?.cancel();
      _ticker = null;
    } else if (state == AppLifecycleState.resumed) {
      _startTicker();
    }
  }

  int _sessionSeconds(BookChapterSummary? summary) {
    final minutes = summary?.estimatedMinutes ?? AppSizes.coreSessionMinutes;
    return minutes.clamp(1, AppSizes.coreSessionMinutes) * 60;
  }

  void _startTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_clock!.tick);
    });
  }

  void _ensureTimerStarted(BookChapterSummary? summary) {
    if (_timerStarted) return;
    _timerStarted = true;
    _clock = SessionClock(totalSeconds: _sessionSeconds(summary));
    _startTicker();
  }

  void _maybeRestorePosition(Chapter chapter) {
    if (_restored) return;
    _restored = true;

    final saved = ref
        .read(readingProgressProvider.notifier)
        .stateFor(widget.bookId, widget.chapterId);
    if (saved.completed) {
      if (saved.paragraphId != null) {
        ref
            .read(readingProgressProvider.notifier)
            .clearPosition(widget.bookId, widget.chapterId);
      }
      return;
    }
    final anchor = saved.paragraphId;
    if (anchor == null) return;

    final known = chapter.paragraphs.any((paragraph) => paragraph.id == anchor);
    if (!known) {
      ref
          .read(readingProgressProvider.notifier)
          .clearPosition(widget.bookId, widget.chapterId);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _paragraphKeys[anchor]?.currentContext;
      if (target == null) return;
      _restoring = true;
      _lastSavedAnchor = anchor;
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: Duration.zero,
      ).whenComplete(() {
        _restoring = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reprise là où vous vous êtes arrêté.')),
      );
    });
  }

  String? _visibleAnchor(Chapter chapter) {
    final threshold = MediaQuery.paddingOf(context).top + kToolbarHeight;
    const tolerance = 24.0;
    String? last;
    for (final paragraph in chapter.paragraphs) {
      final paragraphContext = _paragraphKeys[paragraph.id]?.currentContext;
      if (paragraphContext == null) continue;
      final box = paragraphContext.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      last = paragraph.id;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top >= threshold - tolerance) return paragraph.id;
    }
    return last;
  }

  void _saveAnchor() {
    final chapter = _chapter;
    if (!mounted || chapter == null || _completed || _restoring) return;
    final String? anchor;
    if (_userScrolled) {
      anchor = _visibleAnchor(chapter);
    } else if (_audioPlayed) {
      anchor = _audio?.activeParagraphId;
    } else {
      return;
    }
    if (anchor == null || anchor == _lastSavedAnchor) return;
    _lastSavedAnchor = anchor;
    ref
        .read(readingProgressProvider.notifier)
        .savePosition(widget.bookId, widget.chapterId, anchor);
  }

  Future<void> _completeChapter() async {
    final chapter = _chapter;
    if (_completing || chapter == null) return;
    final elapsedSeconds = _clock?.elapsedSeconds ?? 0;
    final programDay = ref.read(programProgressProvider).currentDay;
    setState(() => _completing = true);
    _ticker?.cancel();
    _ticker = null;
    _followAudio = false;
    _audio?.pause();
    await ref
        .read(readingProgressProvider.notifier)
        .complete(widget.bookId, widget.chapterId);
    final pilot = await ref.read(pilotBookProvider.future);
    if (pilot.id == widget.bookId) {
      await ref
          .read(programProvider.notifier)
          .recordSession(
            at: ref.read(nowProvider)(),
            elapsedSeconds: elapsedSeconds,
          );
    }

    final savedIds = {
      for (final saved in ref.read(savedWordsProvider)) saved.entry.id,
    };
    final added = await ref
        .read(srsProvider.notifier)
        .introduceFromChapter(
          chapter: chapter,
          level: ref.read(userPrefsProvider).level,
          savedIds: savedIds,
        );
    if (!mounted) return;
    unawaited(
      ref
          .read(telemetryProvider.notifier)
          .record(
            'chapter_completed',
            properties: {
              'chapterId': chapter.id,
              'chapterNumber': chapter.number,
              'elapsedSeconds': elapsedSeconds,
              'minutes': math.max(
                1,
                math.min(240, (elapsedSeconds / 60).ceil()),
              ),
              'newWords': added,
              'programDay': programDay,
            },
          ),
    );
    setState(() {
      _completing = false;
      _introducedCount = added;
      _completed = true;
    });
  }

  void _openWord(Chapter chapter, ChapterWord word) {
    final entry = dictionaryEntryFor(chapter, word);
    if (entry == null) return;
    _audio?.pause();
    showWordSheet(context, entry: entry);
  }

  @override
  Widget build(BuildContext context) {
    final request = (bookId: widget.bookId, chapterId: widget.chapterId);
    final chapter = ref.watch(chapterProvider(request));
    final book = ref.watch(bookManifestProvider(widget.bookId));
    final isPilotBook = ref.watch(pilotBookProvider).value?.id == widget.bookId;

    final summary = switch (book) {
      AsyncValue(:final value?) => _findSummary(
        value.chapters,
        widget.chapterId,
      ),
      _ => null,
    };

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveAnchor();
      },
      child: switch (chapter) {
        AsyncError(:final error) => _scaffold(
          _ReadingError(
            onRetry: () => ref.invalidate(chapterProvider(request)),
            message: error is ContentOfflineException
                ? error.message
                : 'Impossible de charger le chapitre.',
          ),
        ),
        AsyncValue(:final value?) when book.hasValue => _buildChapter(
          value,
          summary,
          book.value!,
          isPilotBook: isPilotBook,
        ),
        _ => _scaffold(const Center(child: CircularProgressIndicator())),
      },
    );
  }

  Widget _scaffold(Widget body) => Scaffold(
    appBar: AppBar(title: const Text('Lecture')),
    body: body,
  );

  Widget _buildChapter(
    Chapter chapter,
    BookChapterSummary? summary,
    BookManifest manifest, {
    required bool isPilotBook,
  }) {
    _chapter = chapter;
    _ensureTimerStarted(summary);
    _maybeRestorePosition(chapter);
    if (!_telemetryStarted) {
      _telemetryStarted = true;
      unawaited(
        ref
            .read(telemetryProvider.notifier)
            .record(
              'chapter_started',
              properties: {
                'chapterId': chapter.id,
                'chapterNumber': chapter.number,
              },
            ),
      );
    }

    if (_completed) {
      return _scaffold(
        _ChapterRecap(
          chapter: chapter,
          manifest: manifest,
          isPilotBook: isPilotBook,
          elapsedSeconds: _clock?.elapsedSeconds ?? 0,
          introducedCount: _introducedCount,
          onReturnToPath: () => context.go(isPilotBook ? '/today' : '/library'),
          onClose: () => context.pop(),
        ),
      );
    }

    final hasAudio = chapter.hasAudio;
    final mode = hasAudio ? _mode : ReadingMode.read;
    if (mode.usesAudio) _ensureAudio(chapter);

    final theme = Theme.of(context);
    final minutes = summary?.estimatedMinutes;
    final wide = MediaQuery.sizeOf(context).width >= AppSizes.wideBreakpoint;

    final reader = mode == ReadingMode.listen
        ? AudioListenPanel(controller: _audio!, chapterTitle: chapter.title)
        : _textView(chapter, mode, theme, minutes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecture'),
        actions: [
          const WordListButton(),
          if (_clock case final clock?)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: _SessionBadge(secondsLeft: clock.remainingSeconds),
              ),
            ),
        ],
      ),
      body: wide && mode != ReadingMode.listen
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: reader),
                _ReaderSidePanel(
                  manifest: manifest,
                  chapter: chapter,
                  minutes: minutes,
                  mode: mode,
                  onModeChanged: _setMode,
                  audio: mode == ReadingMode.readListen ? _audio : null,
                ),
              ],
            )
          : Column(
              children: [
                if (hasAudio)
                  _ReadingModeSelector(mode: mode, onChanged: _setMode),
                Expanded(child: reader),
              ],
            ),
      bottomNavigationBar: mode == ReadingMode.readListen && !wide
          ? AudioTransportBar(controller: _audio!)
          : null,
    );
  }

  Widget _textView(
    Chapter chapter,
    ReadingMode mode,
    ThemeData theme,
    int? minutes,
  ) {
    final audio = mode == ReadingMode.readListen ? _audio : null;
    final layouts = chapter.layout.paragraphs;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _userScrolled = true;
          _followAudio = false;
        } else if (notification is ScrollEndNotification) {
          _saveAnchor();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.readingMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chapter.title, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ContentLevelBadge(level: chapter.level.shortLabel),
                          if (minutes != null)
                            Text(
                              '≈ $minutes min',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Touchez un mot surligné pour voir sa '
                              'définition et l’ajouter à votre liste.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final (index, layout) in layouts.indexed)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == layouts.length - 1
                                ? 0
                                : AppSpacing.lg,
                          ),
                          child: Container(
                            key: _paragraphKeys.putIfAbsent(
                              layout.paragraphId,
                              GlobalKey.new,
                            ),
                            child: ChapterParagraphText(
                              key: ValueKey('paragraph-${layout.paragraphId}'),
                              layout: layout,
                              activeWordIndex: audio?.activeWordIndex,
                              activeSentenceIndex: audio?.activeSentenceIndex,
                              track: audio?.track,
                              onWordTap: (word) => _openWord(chapter, word),
                            ),
                          ),
                        ),
                      _EndOfChapter(onComplete: _completeChapter),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BookChapterSummary? _findSummary(
    List<BookChapterSummary> chapters,
    String id,
  ) {
    for (final chapter in chapters) {
      if (chapter.id == id) return chapter;
    }
    return null;
  }
}

class _ReadingModeSelector extends StatelessWidget {
  const _ReadingModeSelector({required this.mode, required this.onChanged});

  final ReadingMode mode;
  final ValueChanged<ReadingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SegmentedButton<ReadingMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            segments: const [
              ButtonSegment(value: ReadingMode.read, label: Text('Lire')),
              ButtonSegment(value: ReadingMode.listen, label: Text('Écouter')),
              ButtonSegment(
                value: ReadingMode.readListen,
                label: Text('Lire + Écouter'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
      ),
    );
  }
}

class _ReaderSidePanel extends StatelessWidget {
  const _ReaderSidePanel({
    required this.manifest,
    required this.chapter,
    required this.minutes,
    required this.mode,
    required this.onModeChanged,
    this.audio,
  });

  final BookManifest manifest;
  final Chapter chapter;
  final int? minutes;
  final ReadingMode mode;
  final ValueChanged<ReadingMode> onModeChanged;
  final AudioSessionController? audio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(left: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    height: 76,
                    child: BookCover(
                      title: manifest.title,
                      seed: manifest.id,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          manifest.titleFr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ContentLevelBadge(level: chapter.level.shortLabel),
                            if (minutes != null)
                              Text(
                                '≈ $minutes min',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ReadingModeSelector(mode: mode, onChanged: onModeChanged),
            const SizedBox(height: AppSpacing.lg),
            if (audio != null) AudioTransportBar(controller: audio!),
          ],
        ),
      ),
    );
  }
}

class _SessionBadge extends StatelessWidget {
  const _SessionBadge({required this.secondsLeft});

  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overtime = secondsLeft < 0;
    final background = overtime
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.secondaryContainer;
    final foreground = overtime
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSecondaryContainer;

    return Semantics(
      label: 'Temps restant',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 16, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Text(
                formatSessionTime(secondsLeft),
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndOfChapter extends StatelessWidget {
  const _EndOfChapter({required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Text('Fin du chapitre', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Marquez ce chapitre comme terminé pour clore votre session.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Terminer le chapitre'),
          ),
        ),
      ],
    );
  }
}

class _ChapterRecap extends ConsumerWidget {
  const _ChapterRecap({
    required this.chapter,
    required this.manifest,
    required this.isPilotBook,
    required this.elapsedSeconds,
    required this.introducedCount,
    required this.onReturnToPath,
    required this.onClose,
  });

  final Chapter chapter;
  final BookManifest manifest;
  final bool isPilotBook;
  final int elapsedSeconds;
  final int introducedCount;
  final VoidCallback onReturnToPath;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queue = ref.watch(reviewQueueProvider);
    final ready = queue.cards.length;
    final progress = ref.watch(programProgressProvider);
    final bookComplete = manifest.chapters.every(
      (summary) => ref
          .read(readingProgressProvider.notifier)
          .stateFor(manifest.id, summary.id)
          .completed,
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Icon(
                  Icons.check_circle,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Chapitre terminé',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  chapter.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (progress.doneToday) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_fire_department_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          'Jour ${progress.currentDay} validé · série de '
                          '${progress.streak} j',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
                if (bookComplete) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              isPilotBook
                                  ? 'Vous avez terminé le livre pilote !'
                                  : 'Vous avez terminé ce livre !',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: _RecapStat(
                            icon: Icons.timer_outlined,
                            value: formatSessionTime(elapsedSeconds),
                            label: 'Temps de lecture',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _RecapStat(
                            icon: Icons.menu_book_outlined,
                            value: '${chapter.vocabulary.length}',
                            label: 'Mots rencontrés',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Mots du chapitre', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final entry in chapter.vocabulary)
                      Chip(
                        label: Text(entry.word),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.style_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Votre révision du jour',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(switch (introducedCount) {
                          0 => 'Aucun nouveau mot à ajouter cette fois-ci.',
                          1 => '1 nouveau mot ajouté à votre révision.',
                          _ =>
                            '$introducedCount nouveaux mots ajoutés à votre révision.',
                        }, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          switch (ready) {
                            0 => 'Vous êtes à jour.',
                            1 => '1 carte prête à réviser.',
                            _ => '$ready cartes prêtes à réviser.',
                          },
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (ready > 0) ...[
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => context.push('/review'),
                              icon: const Icon(Icons.play_arrow_outlined),
                              label: const Text('Réviser ces mots'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: onReturnToPath,
                  child: Text(
                    isPilotBook
                        ? 'Retour au parcours'
                        : 'Retour à la bibliothèque',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: onClose, child: const Text('Fermer')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecapStat extends StatelessWidget {
  const _RecapStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: theme.textTheme.titleLarge),
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

class _ReadingError extends StatelessWidget {
  const _ReadingError({required this.onRetry, required this.message});

  final VoidCallback onRetry;
  final String message;

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
              message,
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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../domain/word_entry.dart';
import '../domain/word_pronouncer.dart';
import 'pronunciation_providers.dart';
import 'saved_words_provider.dart';

Future<void> showWordSheet(BuildContext context, {required WordEntry entry}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => WordSheet(entry: entry),
  );
}

class WordSheet extends ConsumerStatefulWidget {
  const WordSheet({required this.entry, super.key});

  final WordEntry entry;

  @override
  ConsumerState<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends ConsumerState<WordSheet> {
  WordPronouncer? _pronouncer;
  String? _notice;
  bool _noticeIsError = false;

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

  Future<void> _pronounce() async {
    setState(() {
      _notice = null;
      _noticeIsError = false;
    });
    try {
      await _voice.pronounce(word: widget.entry.word, clip: widget.entry.clip);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice = 'Prononciation indisponible.';
        _noticeIsError = true;
      });
    }
  }

  Future<void> _toggleSaved() async {
    final added = await ref
        .read(savedWordsProvider.notifier)
        .toggle(widget.entry);
    if (!mounted) return;
    setState(() {
      _notice = added
          ? 'Ajouté à votre liste de mots.'
          : 'Retiré de votre liste de mots.';
      _noticeIsError = false;
    });
  }

  void _openWordList() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/words');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final saved = ref
        .watch(savedWordsProvider)
        .any((word) => word.entry.id == entry.id);
    final pos = partOfSpeechLabel(entry.partOfSpeech);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.word, style: theme.textTheme.headlineMedium),
                if (entry.phonetic.isNotEmpty || pos.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (entry.phonetic.isNotEmpty)
                        Text(
                          entry.phonetic,
                          style: theme.textTheme.bodyLarge?.copyWith(
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
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            pos,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  entry.translationFr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
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
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exemple',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '“${entry.example}”',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pronounce,
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('Écouter'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _toggleSaved,
                      icon: Icon(
                        saved
                            ? Icons.check_circle_outline
                            : Icons.bookmark_add_outlined,
                      ),
                      label: Text(
                        saved
                            ? 'Dans ma liste de mots'
                            : 'Ajouter à ma liste de mots',
                      ),
                    ),
                  ],
                ),
                if (_notice case final notice?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _noticeIsError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 18,
                        color: _noticeIsError
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          notice,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _noticeIsError
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                TextButton.icon(
                  onPressed: _openWordList,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('Voir ma liste de mots'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

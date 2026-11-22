import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../content/domain/chapter.dart';
import '../domain/karaoke_track.dart';

class ChapterParagraphText extends StatefulWidget {
  const ChapterParagraphText({
    required this.layout,
    this.activeWordIndex,
    this.activeSentenceIndex,
    this.track,
    this.onWordTap,
    super.key,
  });

  final ParagraphLayout layout;
  final int? activeWordIndex;
  final int? activeSentenceIndex;
  final KaraokeTrack? track;
  final ValueChanged<ChapterWord>? onWordTap;

  @override
  State<ChapterParagraphText> createState() => _ChapterParagraphTextState();
}

class _ChapterParagraphTextState extends State<ChapterParagraphText> {
  final Map<int, TapGestureRecognizer> _recognizers = {};

  @override
  void didUpdateWidget(ChapterParagraphText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.layout, widget.layout)) {
      _disposeRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer? _recognizerFor(ParagraphPiece piece) {
    final wordIndex = piece.wordIndex;
    if (wordIndex == null || piece.vocabId == null) return null;
    if (widget.onWordTap == null) return null;
    return _recognizers.putIfAbsent(wordIndex, () {
      return TapGestureRecognizer()
        ..onTap = () {
          final callback = widget.onWordTap;
          final words = widget.layout.words;
          if (callback == null || wordIndex >= words.length) return;
          callback(words[wordIndex]);
        };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.7);
    final vocabStyle = baseStyle?.copyWith(
      backgroundColor: theme.colorScheme.primaryContainer,
      color: theme.colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.w600,
    );
    final activeWordStyle = baseStyle?.copyWith(
      backgroundColor: theme.colorScheme.primary,
      color: theme.colorScheme.onPrimary,
      fontWeight: FontWeight.w700,
    );

    TextStyle? sentenceStyle(TextStyle? style) =>
        (style ?? baseStyle)?.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.secondary,
          decorationThickness: 2,
        );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (final piece in widget.layout.pieces)
            TextSpan(
              text: piece.text,
              style: _pieceStyle(
                piece: piece,
                baseStyle: baseStyle,
                vocabStyle: piece.vocabId != null ? vocabStyle : null,
                activeWordStyle: activeWordStyle,
                sentenceStyle: sentenceStyle,
              ),
              recognizer: _recognizerFor(piece),
              mouseCursor: piece.vocabId != null && widget.onWordTap != null
                  ? SystemMouseCursors.click
                  : null,
            ),
        ],
      ),
    );
  }

  TextStyle? _pieceStyle({
    required ParagraphPiece piece,
    required TextStyle? baseStyle,
    required TextStyle? vocabStyle,
    required TextStyle? activeWordStyle,
    required TextStyle? Function(TextStyle?) sentenceStyle,
  }) {
    if (!piece.isWord) return vocabStyle ?? baseStyle;
    final globalIndex = widget.layout.startWordIndex + piece.wordIndex!;
    if (widget.activeWordIndex == globalIndex) return activeWordStyle;
    final inActiveSentence =
        widget.activeSentenceIndex != null &&
        widget.track?.sentenceIndexAtWord(globalIndex) ==
            widget.activeSentenceIndex;
    final vocabulary = vocabStyle ?? baseStyle;
    return inActiveSentence ? sentenceStyle(vocabulary) : vocabulary;
  }
}

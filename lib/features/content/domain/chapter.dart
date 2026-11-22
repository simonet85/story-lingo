import '../../onboarding/domain/user_level.dart';
import 'content_format_exception.dart';
import 'content_level.dart';
import 'json_reader.dart';

class Chapter {
  Chapter({
    required this.schemaVersion,
    required this.id,
    required this.bookId,
    required this.number,
    required this.title,
    required this.level,
    required this.paragraphs,
    required this.vocabulary,
    this.audio,
  });

  factory Chapter.fromJson(Object? source) {
    final json = requireJsonObject(source, 'chapter');
    final schemaVersion = requireInt(json, 'schemaVersion', 'chapter');
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw ContentFormatException(
        'chapter.schemaVersion: unsupported version $schemaVersion.',
      );
    }

    final rawParagraphs = requireJsonList(
      json['paragraphs'],
      'chapter.paragraphs',
    );
    if (rawParagraphs.isEmpty) {
      throw ContentFormatException(
        'chapter.paragraphs: at least one paragraph is required.',
      );
    }
    final paragraphs = <ChapterParagraph>[];
    for (final (index, raw) in rawParagraphs.indexed) {
      paragraphs.add(
        ChapterParagraph.fromJson(raw, 'chapter.paragraphs[$index]'),
      );
    }

    final rawVocabulary = requireJsonList(
      json['vocabulary'],
      'chapter.vocabulary',
    );
    final vocabulary = <VocabularyEntry>[];
    for (final (index, raw) in rawVocabulary.indexed) {
      vocabulary.add(
        VocabularyEntry.fromJson(raw, 'chapter.vocabulary[$index]'),
      );
    }

    final audio = schemaVersion == 2
        ? ChapterAudio.fromJson(json['audio'], 'chapter.audio')
        : null;

    final chapter = Chapter(
      schemaVersion: schemaVersion,
      id: requireString(json, 'id', 'chapter'),
      bookId: requireString(json, 'bookId', 'chapter'),
      number: requireIntAtLeast(json, 'number', 'chapter', 1),
      title: requireString(json, 'title', 'chapter'),
      level: parseContentLevel(json['level'], 'chapter.level'),
      paragraphs: List.unmodifiable(paragraphs),
      vocabulary: List.unmodifiable(vocabulary),
      audio: audio,
    );
    chapter._validateVocabularyUsage();
    chapter._validateAudio();
    return chapter;
  }

  final int schemaVersion;
  final String id;
  final String bookId;
  final int number;
  final String title;
  final UserLevel level;
  final List<ChapterParagraph> paragraphs;
  final List<VocabularyEntry> vocabulary;
  final ChapterAudio? audio;

  ChapterLayout? _layout;

  ChapterLayout get layout =>
      _layout ??= ChapterLayout.fromParagraphs(paragraphs);

  bool get hasAudio => audio != null;

  Chapter withAudio(ChapterAudio? audio) => Chapter(
    schemaVersion: schemaVersion,
    id: id,
    bookId: bookId,
    number: number,
    title: title,
    level: level,
    paragraphs: paragraphs,
    vocabulary: vocabulary,
    audio: audio,
  );

  int get wordCount => paragraphs
      .expand((paragraph) => paragraph.segments)
      .expand((segment) => segment.text.split(RegExp(r'\s+')))
      .where((word) => word.isNotEmpty)
      .length;

  VocabularyEntry? vocabularyById(String? vocabId) {
    for (final entry in vocabulary) {
      if (entry.id == vocabId) return entry;
    }
    return null;
  }

  void _validateAudio() {
    final audio = this.audio;
    if (audio == null) return;
    final words = layout.words;
    if (words.length != audio.words.length) {
      throw ContentFormatException(
        'chapter.audio.words: expected ${words.length} timings for the '
        'chapter tokens, got ${audio.words.length}.',
      );
    }
    for (final (index, word) in words.indexed) {
      final timing = audio.words[index];
      if (normalizeWord(word.text) != normalizeWord(timing.text)) {
        throw ContentFormatException(
          'chapter.audio.words[$index]: "${timing.text}" does not match '
          'chapter token "${word.text}".',
        );
      }
    }
  }

  void _validateVocabularyUsage() {
    final knownIds = <String>{};
    for (final entry in vocabulary) {
      if (!knownIds.add(entry.id)) {
        throw ContentFormatException(
          'chapter.vocabulary: duplicate vocabulary id "${entry.id}".',
        );
      }
    }

    final referencedIds = <String>{};
    for (final paragraph in paragraphs) {
      for (final segment in paragraph.segments) {
        final vocabId = segment.vocabId;
        if (vocabId == null) continue;
        if (!knownIds.contains(vocabId)) {
          throw ContentFormatException(
            'chapter.paragraphs.${paragraph.id}: unknown vocabId "$vocabId".',
          );
        }
        referencedIds.add(vocabId);
      }
    }

    for (final entry in vocabulary) {
      if (!referencedIds.contains(entry.id)) {
        throw ContentFormatException(
          'chapter.vocabulary: "${entry.id}" is never used in the text.',
        );
      }
    }
  }
}

class ChapterParagraph {
  const ChapterParagraph({required this.id, required this.segments});

  factory ChapterParagraph.fromJson(Object? source, String path) {
    final json = requireJsonObject(source, path);
    final rawSegments = requireJsonList(json['segments'], '$path.segments');
    if (rawSegments.isEmpty) {
      throw ContentFormatException(
        '$path.segments: at least one segment is required.',
      );
    }
    final segments = <TextSegment>[];
    for (final (index, raw) in rawSegments.indexed) {
      segments.add(TextSegment.fromJson(raw, '$path.segments[$index]'));
    }
    return ChapterParagraph(
      id: requireString(json, 'id', path),
      segments: List.unmodifiable(segments),
    );
  }

  final String id;
  final List<TextSegment> segments;

  String get text => segments.map((segment) => segment.text).join();
}

class TextSegment {
  const TextSegment({required this.text, this.vocabId});

  factory TextSegment.fromJson(Object? source, String path) {
    final json = requireJsonObject(source, path);
    return TextSegment(
      text: requireString(json, 'text', path),
      vocabId: optionalString(json, 'vocabId', path),
    );
  }

  final String text;
  final String? vocabId;

  bool get isAnnotated => vocabId != null;
}

class VocabularyEntry {
  const VocabularyEntry({
    required this.id,
    required this.word,
    required this.partOfSpeech,
    required this.phonetic,
    required this.definitionEn,
    required this.translationFr,
    required this.example,
    this.cefr,
  });

  factory VocabularyEntry.fromJson(Object? source, String path) {
    final json = requireJsonObject(source, path);
    return VocabularyEntry(
      id: requireString(json, 'id', path),
      word: requireString(json, 'word', path),
      partOfSpeech: requireString(json, 'partOfSpeech', path),
      phonetic: requireString(json, 'phonetic', path),
      definitionEn: requireString(json, 'definitionEn', path),
      translationFr: requireString(json, 'translationFr', path),
      example: requireString(json, 'example', path),
      cefr: json['cefr'] == null
          ? null
          : parseContentLevel(json['cefr'], '$path.cefr'),
    );
  }

  final String id;
  final String word;
  final String partOfSpeech;
  final String phonetic;
  final String definitionEn;
  final String translationFr;
  final String example;

  /// CEFR level of the word itself, when the pack provides one.
  final UserLevel? cefr;
}

class ChapterAudio {
  const ChapterAudio({
    this.asset,
    this.url,
    this.localFile,
    required this.durationMs,
    required this.voice,
    required this.words,
  });

  factory ChapterAudio.fromJson(Object? source, String path) {
    final json = requireJsonObject(source, path);
    final asset = optionalString(json, 'asset', path);
    final url = optionalString(json, 'url', path);
    if ((asset == null) == (url == null)) {
      throw ContentFormatException(
        '$path: exactly one of "asset" or "url" is required.',
      );
    }
    final rawWords = requireJsonList(json['words'], '$path.words');
    if (rawWords.isEmpty) {
      throw ContentFormatException(
        '$path.words: at least one timing is required.',
      );
    }

    final words = <AudioWordTiming>[];
    var previousStart = -1;
    var previousEnd = -1;
    for (final (index, raw) in rawWords.indexed) {
      final timing = AudioWordTiming.fromJson(raw, '$path.words[$index]');
      if (timing.startMs <= previousStart) {
        throw ContentFormatException(
          '$path.words[$index].startMs: expected a strictly increasing '
          'value, got ${timing.startMs} after $previousStart.',
        );
      }
      if (timing.startMs < previousEnd) {
        throw ContentFormatException(
          '$path.words[$index].startMs: overlaps the previous timing.',
        );
      }
      previousStart = timing.startMs;
      previousEnd = timing.endMs;
      words.add(timing);
    }

    final durationMs = requireIntAtLeast(json, 'durationMs', path, 1);
    if (durationMs < words.last.endMs) {
      throw ContentFormatException(
        '$path.durationMs ($durationMs) is before the last word end '
        '(${words.last.endMs}).',
      );
    }

    return ChapterAudio(
      asset: asset,
      url: url,
      durationMs: durationMs,
      voice: requireString(json, 'voice', path),
      words: List.unmodifiable(words),
    );
  }

  final String? asset;
  final String? url;

  /// Absolute path of the downloaded file, when reading from an installed pack.
  final String? localFile;
  final int durationMs;
  final String voice;
  final List<AudioWordTiming> words;

  bool get isRemote => url != null;

  String get location => asset ?? url!;

  ChapterAudio withLocalFile(String? path) => ChapterAudio(
    asset: asset,
    url: url,
    localFile: path,
    durationMs: durationMs,
    voice: voice,
    words: words,
  );
}

class AudioWordTiming {
  const AudioWordTiming({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  factory AudioWordTiming.fromJson(Object? source, String path) {
    final json = requireJsonObject(source, path);
    final startMs = requireIntAtLeast(json, 'startMs', path, 0);
    final endMs = requireInt(json, 'endMs', path);
    if (endMs <= startMs) {
      throw ContentFormatException(
        '$path.endMs: expected a value greater than startMs ($startMs), '
        'got $endMs.',
      );
    }
    return AudioWordTiming(
      text: requireString(json, 'text', path),
      startMs: startMs,
      endMs: endMs,
    );
  }

  final String text;
  final int startMs;
  final int endMs;

  Duration get start => Duration(milliseconds: startMs);
  Duration get end => Duration(milliseconds: endMs);
}

final RegExp _wordPattern = RegExp(r"[A-Za-z0-9]+(?:[’'][A-Za-z0-9]+)*[’']?");
final RegExp _sentenceTerminator = RegExp(r'[.!?…]');
final RegExp _normalizeKeep = RegExp(r"[a-z0-9']");
final RegExp _trailingApostrophes = RegExp(r"'+$");

String normalizeWord(String word) {
  final lower = word.replaceAll('’', "'").toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    if (_normalizeKeep.hasMatch(char)) buffer.write(char);
  }
  return buffer.toString().replaceAll(_trailingApostrophes, '');
}

class ParagraphPiece {
  const ParagraphPiece({required this.text, this.wordIndex, this.vocabId});

  final String text;

  /// Index of the word within its paragraph, or `null` for gaps.
  final int? wordIndex;
  final String? vocabId;

  bool get isWord => wordIndex != null;
}

class ChapterWord {
  const ChapterWord({
    required this.index,
    required this.paragraphIndex,
    required this.paragraphId,
    required this.indexInParagraph,
    required this.text,
    required this.vocabId,
    required this.endsSentence,
  });

  /// Global index across the whole chapter, aligned with audio timings.
  final int index;
  final int paragraphIndex;
  final String paragraphId;
  final int indexInParagraph;
  final String text;
  final String? vocabId;
  final bool endsSentence;
}

class ParagraphLayout {
  const ParagraphLayout({
    required this.paragraphId,
    required this.pieces,
    required this.words,
  });

  final String paragraphId;
  final List<ParagraphPiece> pieces;
  final List<ChapterWord> words;

  int get startWordIndex => words.isEmpty ? 0 : words.first.index;
}

class ChapterLayout {
  const ChapterLayout({required this.paragraphs, required this.words});

  factory ChapterLayout.fromParagraphs(List<ChapterParagraph> paragraphs) {
    final layouts = <ParagraphLayout>[];
    final allWords = <ChapterWord>[];

    for (final (paragraphIndex, paragraph) in paragraphs.indexed) {
      final pieces = <ParagraphPiece>[];
      final words = <ChapterWord>[];
      final buffer = StringBuffer();
      final ranges = <_SegmentRange>[];
      for (final segment in paragraph.segments) {
        final start = buffer.length;
        buffer.write(segment.text);
        ranges.add(
          _SegmentRange(
            start: start,
            end: buffer.length,
            vocabId: segment.vocabId,
          ),
        );
      }
      final text = buffer.toString();
      final matches = _wordPattern.allMatches(text).toList();

      var cursor = 0;
      for (final (wordIndex, match) in matches.indexed) {
        if (match.start > cursor) {
          _emitGap(
            pieces: pieces,
            text: text,
            start: cursor,
            end: match.start,
            ranges: ranges,
          );
        }
        final range = _rangeAt(ranges, match.start);
        if (range == null || match.end > range.end) {
          throw ContentFormatException(
            'chapter.paragraphs[${paragraph.id}]: the token '
            '"${match.group(0)}" crosses a segment boundary.',
          );
        }
        final wordText = match.group(0)!;
        final nextStart = wordIndex + 1 < matches.length
            ? matches[wordIndex + 1].start
            : text.length;
        final gap = text.substring(match.end, nextStart);
        final endsSentence =
            wordIndex + 1 == matches.length ||
            _sentenceTerminator.hasMatch(gap);
        final word = ChapterWord(
          index: allWords.length,
          paragraphIndex: paragraphIndex,
          paragraphId: paragraph.id,
          indexInParagraph: wordIndex,
          text: wordText,
          vocabId: range.vocabId,
          endsSentence: endsSentence,
        );
        pieces.add(
          ParagraphPiece(
            text: wordText,
            wordIndex: wordIndex,
            vocabId: range.vocabId,
          ),
        );
        words.add(word);
        allWords.add(word);
        cursor = match.end;
      }
      if (cursor < text.length) {
        _emitGap(
          pieces: pieces,
          text: text,
          start: cursor,
          end: text.length,
          ranges: ranges,
        );
      }

      layouts.add(
        ParagraphLayout(
          paragraphId: paragraph.id,
          pieces: List.unmodifiable(pieces),
          words: List.unmodifiable(words),
        ),
      );
    }

    return ChapterLayout(
      paragraphs: List.unmodifiable(layouts),
      words: List.unmodifiable(allWords),
    );
  }

  final List<ParagraphLayout> paragraphs;
  final List<ChapterWord> words;
}

class _SegmentRange {
  const _SegmentRange({
    required this.start,
    required this.end,
    required this.vocabId,
  });

  final int start;
  final int end;
  final String? vocabId;
}

_SegmentRange? _rangeAt(List<_SegmentRange> ranges, int position) {
  for (final range in ranges) {
    if (position >= range.start && position < range.end) return range;
  }
  return null;
}

void _emitGap({
  required List<ParagraphPiece> pieces,
  required String text,
  required int start,
  required int end,
  required List<_SegmentRange> ranges,
}) {
  var position = start;
  while (position < end) {
    final range = _rangeAt(ranges, position);
    final gapEnd = range == null ? end : (end < range.end ? end : range.end);
    pieces.add(
      ParagraphPiece(
        text: text.substring(position, gapEnd),
        vocabId: range?.vocabId,
      ),
    );
    position = gapEnd;
  }
}

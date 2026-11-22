class PronunciationClip {
  const PronunciationClip({
    required this.asset,
    required this.start,
    required this.end,
  });

  final String asset;
  final Duration start;
  final Duration end;

  Duration get duration => end - start;

  Map<String, Object> toJson() => {
    'asset': asset,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
  };

  static PronunciationClip? fromJson(Object? source) {
    if (source is! Map) return null;
    final asset = source['asset'];
    final startMs = source['startMs'];
    final endMs = source['endMs'];
    if (asset is! String || asset.isEmpty) return null;
    if (startMs is! int || endMs is! int) return null;
    if (startMs < 0 || endMs <= startMs) return null;
    return PronunciationClip(
      asset: asset,
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
    );
  }
}

class WordEntry {
  const WordEntry({
    required this.id,
    required this.word,
    required this.partOfSpeech,
    required this.phonetic,
    required this.definitionEn,
    required this.translationFr,
    required this.example,
    required this.bookId,
    required this.chapterId,
    this.clip,
  });

  /// Stable identity across the app: `${bookId}/${vocabularyId}`.
  final String id;
  final String word;
  final String partOfSpeech;
  final String phonetic;
  final String definitionEn;
  final String translationFr;
  final String example;
  final String bookId;
  final String chapterId;
  final PronunciationClip? clip;

  Map<String, Object?> toJson() => {
    'id': id,
    'word': word,
    'partOfSpeech': partOfSpeech,
    'phonetic': phonetic,
    'definitionEn': definitionEn,
    'translationFr': translationFr,
    'example': example,
    'bookId': bookId,
    'chapterId': chapterId,
    'clip': clip?.toJson(),
  };

  static WordEntry? fromJson(Object? source) {
    if (source is! Map) return null;
    final id = source['id'];
    final word = source['word'];
    if (id is! String || id.isEmpty || word is! String || word.isEmpty) {
      return null;
    }
    String read(String key) {
      final value = source[key];
      return value is String ? value : '';
    }

    return WordEntry(
      id: id,
      word: word,
      partOfSpeech: read('partOfSpeech'),
      phonetic: read('phonetic'),
      definitionEn: read('definitionEn'),
      translationFr: read('translationFr'),
      example: read('example'),
      bookId: read('bookId'),
      chapterId: read('chapterId'),
      clip: PronunciationClip.fromJson(source['clip']),
    );
  }
}

class SavedWord {
  const SavedWord({required this.entry, required this.savedAt});

  final WordEntry entry;
  final DateTime savedAt;

  Map<String, Object?> toJson() => {
    ...entry.toJson(),
    'savedAt': savedAt.millisecondsSinceEpoch,
  };

  static SavedWord? fromJson(Object? source) {
    final entry = WordEntry.fromJson(source);
    if (entry == null) return null;
    final rawSavedAt = source is Map ? source['savedAt'] : null;
    final savedAt = rawSavedAt is int
        ? DateTime.fromMillisecondsSinceEpoch(rawSavedAt)
        : DateTime.fromMillisecondsSinceEpoch(0);
    return SavedWord(entry: entry, savedAt: savedAt);
  }
}

String partOfSpeechLabel(String partOfSpeech) {
  final normalized = partOfSpeech.trim().toLowerCase();
  return switch (normalized) {
    'noun' => 'nom',
    'proper noun' => 'nom propre',
    'verb' => 'verbe',
    'adjective' => 'adjectif',
    'adverb' => 'adverbe',
    'pronoun' => 'pronom',
    'preposition' => 'préposition',
    'conjunction' => 'conjonction',
    'interjection' => 'interjection',
    _ => partOfSpeech.trim(),
  };
}

import '../../content/domain/chapter.dart';
import '../../content/domain/chapter_dictionary.dart';
import '../../onboarding/domain/user_level.dart';
import 'word_entry.dart';

const int minimumSessionWords = 5;

/// Selects the chapter words worth teaching to a user at [level].
///
/// Words saved by the user always qualify; otherwise a word qualifies when
/// its own CEFR level is at or above the user level (unknown level counts).
/// Proper nouns never become cards. When fewer than [minimum] words qualify
/// the hardest remaining words complete the session, so a single easier book
/// still yields a review.
List<WordEntry> detectNewWords({
  required Chapter chapter,
  required UserLevel level,
  required Set<String> introducedIds,
  Set<String> savedIds = const {},
  int minimum = minimumSessionWords,
}) {
  bool isCardWorthy(VocabularyEntry vocabulary) =>
      vocabulary.partOfSpeech.trim().toLowerCase() != 'proper noun';
  String idOf(VocabularyEntry vocabulary) =>
      '${chapter.bookId}/${vocabulary.id}';

  final order = <String, int>{
    for (final (index, vocabulary) in chapter.vocabulary.indexed)
      vocabulary.id: index,
  };

  final pool = <VocabularyEntry>[
    for (final vocabulary in chapter.vocabulary)
      if (isCardWorthy(vocabulary) && !introducedIds.contains(idOf(vocabulary)))
        vocabulary,
  ]..sort((a, b) {
    final byLevel = (b.cefr?.index ?? -1).compareTo(a.cefr?.index ?? -1);
    return byLevel != 0 ? byLevel : order[a.id]!.compareTo(order[b.id]!);
  });

  final selected = <VocabularyEntry>[];
  final selectedIds = <String>{};

  for (final vocabulary in pool) {
    if (savedIds.contains(idOf(vocabulary))) {
      selected.add(vocabulary);
      selectedIds.add(vocabulary.id);
    }
  }

  final primary = <VocabularyEntry>[
    for (final vocabulary in pool)
      if (!selectedIds.contains(vocabulary.id) &&
          (vocabulary.cefr == null ||
              vocabulary.cefr!.index >= level.index))
        vocabulary,
  ];
  for (final vocabulary in primary) {
    selected.add(vocabulary);
    selectedIds.add(vocabulary.id);
  }

  for (final vocabulary in pool) {
    if (selected.length >= minimum) break;
    if (!selectedIds.add(vocabulary.id)) continue;
    selected.add(vocabulary);
  }

  final entries = <WordEntry>[];
  for (final vocabulary in selected) {
    final entry = dictionaryEntryForVocabularyId(chapter, vocabulary.id);
    if (entry != null) entries.add(entry);
  }
  return entries;
}

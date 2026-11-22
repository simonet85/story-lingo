import '../../vocabulary/domain/word_entry.dart';
import 'chapter.dart';

WordEntry? dictionaryEntryForVocabularyId(Chapter chapter, String vocabId) {
  for (final word in chapter.layout.words) {
    if (word.vocabId == vocabId) return dictionaryEntryFor(chapter, word);
  }
  return null;
}

WordEntry? dictionaryEntryFor(Chapter chapter, ChapterWord word) {
  final vocabId = word.vocabId;
  if (vocabId == null) return null;
  final vocabulary = chapter.vocabularyById(vocabId);
  if (vocabulary == null) return null;

  return WordEntry(
    id: '${chapter.bookId}/$vocabId',
    word: vocabulary.word,
    partOfSpeech: vocabulary.partOfSpeech,
    phonetic: vocabulary.phonetic,
    definitionEn: vocabulary.definitionEn,
    translationFr: vocabulary.translationFr,
    example: vocabulary.example,
    bookId: chapter.bookId,
    chapterId: chapter.id,
    clip: _clipFor(chapter, word),
  );
}

PronunciationClip? _clipFor(Chapter chapter, ChapterWord word) {
  final audio = chapter.audio;
  if (audio == null || audio.asset == null) return null;

  final paragraphs = chapter.layout.paragraphs;
  if (word.paragraphIndex >= paragraphs.length) return null;
  final paragraph = paragraphs[word.paragraphIndex];

  var first = word.indexInParagraph;
  var last = first;
  while (first > 0 && paragraph.words[first - 1].vocabId == word.vocabId) {
    first--;
  }
  while (last + 1 < paragraph.words.length &&
      paragraph.words[last + 1].vocabId == word.vocabId) {
    last++;
  }

  final startIndex = paragraph.words[first].index;
  final endIndex = paragraph.words[last].index;
  if (endIndex >= audio.words.length) return null;

  return PronunciationClip(
    asset: audio.asset!,
    start: audio.words[startIndex].start,
    end: audio.words[endIndex].end,
  );
}

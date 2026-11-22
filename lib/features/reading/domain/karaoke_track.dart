import '../../content/domain/chapter.dart';

/// Maps an audio position to the active chapter word and sentence.
class KaraokeTrack {
  KaraokeTrack.fromChapter(Chapter chapter)
    : layout = chapter.layout,
      timings = chapter.audio?.words ?? const <AudioWordTiming>[] {
    final sentenceIds = <int>[];
    var sentence = 0;
    for (final word in layout.words) {
      sentenceIds.add(sentence);
      if (word.endsSentence) sentence++;
    }
    _sentenceOfWord = List.unmodifiable(sentenceIds);
    _sentenceCount = sentence;
  }

  final ChapterLayout layout;
  final List<AudioWordTiming> timings;
  late final List<int> _sentenceOfWord;
  late final int _sentenceCount;

  bool get isAvailable =>
      timings.isNotEmpty && timings.length == layout.words.length;

  int get sentenceCount => _sentenceCount;

  /// Index of the word being spoken at [position].
  ///
  /// Before the first timing the first word is active; after the last
  /// timing the last word stays active.
  int? wordIndexAt(Duration position) {
    if (timings.isEmpty || layout.words.isEmpty) return null;
    final ms = position.inMilliseconds;
    if (ms < timings.first.startMs) return 0;

    var low = 0;
    var high = timings.length - 1;
    var found = 0;
    while (low <= high) {
      final middle = (low + high) >> 1;
      if (timings[middle].startMs <= ms) {
        found = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return found;
  }

  int? sentenceIndexAtWord(int wordIndex) {
    if (wordIndex < 0 || wordIndex >= _sentenceOfWord.length) return null;
    return _sentenceOfWord[wordIndex];
  }

  int? paragraphIndexAtWord(int wordIndex) {
    if (wordIndex < 0 || wordIndex >= layout.words.length) return null;
    return layout.words[wordIndex].paragraphIndex;
  }

  String? paragraphIdAtWord(int wordIndex) {
    if (wordIndex < 0 || wordIndex >= layout.words.length) return null;
    return layout.words[wordIndex].paragraphId;
  }
}

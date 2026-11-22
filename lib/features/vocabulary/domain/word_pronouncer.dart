import 'word_entry.dart';

abstract interface class WordPronouncer {
  Future<void> pronounce({required String word, PronunciationClip? clip});

  Future<void> stop();
}

abstract interface class ClipPronouncer {
  Future<void> play(PronunciationClip clip);

  Future<void> stop();
}

abstract interface class TtsPronouncer {
  Future<void> speak(String word);

  Future<void> stop();
}

class PronunciationException implements Exception {
  const PronunciationException();

  @override
  String toString() => 'PronunciationException';
}

class PackWordPronouncer implements WordPronouncer {
  const PackWordPronouncer({required this.clip, required this.tts});

  final ClipPronouncer clip;
  final TtsPronouncer tts;

  @override
  Future<void> pronounce({
    required String word,
    PronunciationClip? clip,
  }) async {
    await stop();
    if (clip != null) {
      try {
        await this.clip.play(clip);
        return;
      } catch (_) {
        // The pack clip is best-effort; fall back to the device voice.
      }
    }
    try {
      await tts.speak(word);
    } catch (_) {
      throw const PronunciationException();
    }
  }

  @override
  Future<void> stop() async {
    try {
      await clip.stop();
    } catch (_) {
      // Stopping must never surface to the UI.
    }
    try {
      await tts.stop();
    } catch (_) {
      // Stopping must never surface to the UI.
    }
  }
}

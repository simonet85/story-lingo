import 'package:flutter_tts/flutter_tts.dart';

import '../domain/word_pronouncer.dart';

class PlatformTtsPronouncer implements TtsPronouncer {
  PlatformTtsPronouncer({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  @override
  Future<void> speak(String word) async {
    if (!_configured) {
      await _tts.setLanguage('en-US');
      _configured = true;
    }
    final result = await _tts.speak(word);
    if (result is int && result != 1) {
      throw const PronunciationException();
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // The platform engine may not be available.
    }
  }

  Future<void> dispose() => stop();
}

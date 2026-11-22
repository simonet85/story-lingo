import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../domain/word_entry.dart';
import '../domain/word_pronouncer.dart';

class JustAudioClipPronouncer implements ClipPronouncer {
  JustAudioClipPronouncer() : _player = AudioPlayer();

  final AudioPlayer _player;
  Timer? _stopTimer;

  @override
  Future<void> play(PronunciationClip clip) async {
    _stopTimer?.cancel();
    await _player.setAsset(clip.asset);
    await _player.seek(clip.start);
    unawaited(_player.play());
    _stopTimer = Timer(clip.duration + const Duration(milliseconds: 150), () {
      _player.pause().ignore();
    });
  }

  @override
  Future<void> stop() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    try {
      await _player.stop();
    } catch (_) {
      // The player may already be disposed.
    }
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}

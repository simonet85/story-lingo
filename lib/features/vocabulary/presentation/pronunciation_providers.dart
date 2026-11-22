import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/just_audio_clip_pronouncer.dart';
import '../data/platform_tts_pronouncer.dart';
import '../domain/word_pronouncer.dart';

final wordPronouncerProvider = Provider<WordPronouncer>((ref) {
  final clip = JustAudioClipPronouncer();
  final tts = PlatformTtsPronouncer();
  ref.onDispose(() {
    unawaited(clip.dispose());
    unawaited(tts.dispose());
  });
  return PackWordPronouncer(clip: clip, tts: tts);
});

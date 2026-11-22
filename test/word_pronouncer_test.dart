import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/vocabulary/domain/word_entry.dart';
import 'package:storylingo/features/vocabulary/domain/word_pronouncer.dart';

class _FakeClipPronouncer implements ClipPronouncer {
  _FakeClipPronouncer({this.failPlay = false, this.failStop = false});

  final bool failPlay;
  final bool failStop;
  final List<PronunciationClip> played = [];
  int stops = 0;

  @override
  Future<void> play(PronunciationClip clip) async {
    if (failPlay) throw StateError('clip failed');
    played.add(clip);
  }

  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('clip stop failed');
  }
}

class _FakeTtsPronouncer implements TtsPronouncer {
  _FakeTtsPronouncer({this.failSpeak = false, this.failStop = false});

  final bool failSpeak;
  final bool failStop;
  final List<String> spoken = [];
  int stops = 0;

  @override
  Future<void> speak(String word) async {
    if (failSpeak) throw StateError('tts failed');
    spoken.add(word);
  }

  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('tts stop failed');
  }
}

const _clip = PronunciationClip(
  asset: 'assets/content/sleepy-hollow-a2/audio/chapter-01.mp3',
  start: Duration(milliseconds: 300),
  end: Duration(milliseconds: 700),
);

void main() {
  test('plays the pack clip first and never calls the device voice', () async {
    final clip = _FakeClipPronouncer();
    final tts = _FakeTtsPronouncer();
    final pronouncer = PackWordPronouncer(clip: clip, tts: tts);

    await pronouncer.pronounce(word: 'mist', clip: _clip);

    expect(clip.played, [_clip]);
    expect(tts.spoken, isEmpty);
    expect(clip.stops, 1);
    expect(tts.stops, 1);
  });

  test('uses the device voice when no clip is available', () async {
    final clip = _FakeClipPronouncer();
    final tts = _FakeTtsPronouncer();
    final pronouncer = PackWordPronouncer(clip: clip, tts: tts);

    await pronouncer.pronounce(word: 'Sleepy Hollow');

    expect(clip.played, isEmpty);
    expect(tts.spoken, ['Sleepy Hollow']);
  });

  test('falls back to the device voice when the pack clip fails', () async {
    final clip = _FakeClipPronouncer(failPlay: true);
    final tts = _FakeTtsPronouncer();
    final pronouncer = PackWordPronouncer(clip: clip, tts: tts);

    await pronouncer.pronounce(word: 'mist', clip: _clip);

    expect(tts.spoken, ['mist']);
  });

  test('throws a pronunciation error when both voices fail', () async {
    final clip = _FakeClipPronouncer(failPlay: true);
    final tts = _FakeTtsPronouncer(failSpeak: true);
    final pronouncer = PackWordPronouncer(clip: clip, tts: tts);

    await expectLater(
      pronouncer.pronounce(word: 'mist', clip: _clip),
      throwsA(isA<PronunciationException>()),
    );
  });

  test('stopping both voices never surfaces their errors', () async {
    final clip = _FakeClipPronouncer(failStop: true);
    final tts = _FakeTtsPronouncer(failStop: true);
    final pronouncer = PackWordPronouncer(clip: clip, tts: tts);

    await pronouncer.stop();

    expect(clip.stops, 1);
    expect(tts.stops, 1);
  });
}

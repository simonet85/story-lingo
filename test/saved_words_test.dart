import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/features/vocabulary/data/saved_words_repository.dart';
import 'package:storylingo/features/vocabulary/domain/word_entry.dart';
import 'package:storylingo/features/vocabulary/presentation/saved_words_provider.dart';

const _clip = PronunciationClip(
  asset: 'assets/content/sleepy-hollow-a2/audio/chapter-01.mp3',
  start: Duration(milliseconds: 300),
  end: Duration(milliseconds: 700),
);

WordEntry _entry(String word, {String? id, PronunciationClip? clip = _clip}) {
  return WordEntry(
    id: id ?? 'sleepy-hollow/${word.toLowerCase()}',
    word: word,
    partOfSpeech: 'noun',
    phonetic: '/mɪst/',
    definitionEn: 'thin fog close to the ground',
    translationFr: 'la brume',
    example: 'A cold mist covered the fields.',
    bookId: 'sleepy-hollow',
    chapterId: 'chapter-01',
    clip: clip,
  );
}

SavedWord _saved(WordEntry entry, {int savedAt = 1000}) {
  return SavedWord(
    entry: entry,
    savedAt: DateTime.fromMillisecondsSinceEpoch(savedAt),
  );
}

void main() {
  group('SavedWordsRepository', () {
    test('round-trips words, clips and timestamps', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SavedWordsRepository(prefs);

      await repository.save([_saved(_entry('mist'))]);
      final reloaded = SavedWordsRepository(prefs).load();

      expect(reloaded, hasLength(1));
      final saved = reloaded.single;
      expect(saved.entry.id, 'sleepy-hollow/mist');
      expect(saved.entry.word, 'mist');
      expect(saved.entry.translationFr, 'la brume');
      expect(saved.entry.clip!.start, const Duration(milliseconds: 300));
      expect(saved.entry.clip!.end, const Duration(milliseconds: 700));
      expect(saved.savedAt.millisecondsSinceEpoch, 1000);
      expect(prefs.get(PrefsKeys.savedWords), isA<List<String>>());
    });

    test('keeps the insertion order and ignores malformed entries', () async {
      final validFirst = jsonEncode(_saved(_entry('mist')).toJson());
      final validSecond = jsonEncode(
        _saved(_entry('ghost'), savedAt: 2000).toJson(),
      );
      SharedPreferences.setMockInitialValues({
        PrefsKeys.savedWords: <String>[
          'not json',
          '{"id": "", "word": "ghost"}',
          validFirst,
          validFirst,
          validSecond,
          '42',
        ],
      });
      final prefs = await SharedPreferences.getInstance();

      final words = SavedWordsRepository(prefs).load();

      expect(words.map((word) => word.entry.word), ['mist', 'ghost']);
    });

    test('loads an empty list when nothing was saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(SavedWordsRepository(prefs).load(), isEmpty);
    });
  });

  group('savedWordsProvider', () {
    late SharedPreferences prefs;
    late SavedWordsRepository repository;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = SavedWordsRepository(prefs);
      container = ProviderContainer(
        overrides: [savedWordsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    test('toggles a word on and off, persisting each state', () async {
      final controller = container.read(savedWordsProvider.notifier);

      final added = await controller.toggle(_entry('mist'));

      expect(added, isTrue);
      expect(controller.contains('sleepy-hollow/mist'), isTrue);
      expect(container.read(savedWordsProvider), hasLength(1));
      expect(SavedWordsRepository(prefs).load(), hasLength(1));

      final removed = await controller.toggle(_entry('mist'));

      expect(removed, isFalse);
      expect(controller.contains('sleepy-hollow/mist'), isFalse);
      expect(container.read(savedWordsProvider), isEmpty);
      expect(SavedWordsRepository(prefs).load(), isEmpty);
    });

    test('keeps several words in insertion order', () async {
      final controller = container.read(savedWordsProvider.notifier);

      await controller.toggle(_entry('mist'));
      await controller.toggle(_entry('ghost'));

      expect(
        container.read(savedWordsProvider).map((word) => word.entry.word),
        ['mist', 'ghost'],
      );
      expect(
        SavedWordsRepository(prefs).load().map((word) => word.entry.word),
        ['mist', 'ghost'],
      );
    });

    test('remove is a no-op for unknown or absent words', () async {
      final controller = container.read(savedWordsProvider.notifier);

      await controller.remove('sleepy-hollow/ghost');

      expect(container.read(savedWordsProvider), isEmpty);
      expect(prefs.getStringList(PrefsKeys.savedWords), isNull);
    });
  });
}

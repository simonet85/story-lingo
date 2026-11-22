import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/prefs_keys.dart';
import '../domain/word_entry.dart';

class SavedWordsRepository {
  SavedWordsRepository(this._prefs);

  final SharedPreferences _prefs;

  List<SavedWord> load() {
    final raw = _prefs.get(PrefsKeys.savedWords);
    if (raw is! List) return const [];
    final words = <SavedWord>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! String) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(item);
      } on FormatException {
        continue;
      }
      final saved = SavedWord.fromJson(decoded);
      if (saved == null || !seen.add(saved.entry.id)) continue;
      words.add(saved);
    }
    return List.unmodifiable(words);
  }

  Future<void> save(List<SavedWord> words) {
    return _prefs.setStringList(PrefsKeys.savedWords, [
      for (final word in words) jsonEncode(word.toJson()),
    ]);
  }

  Map<String, int> loadTombstones() {
    final raw = _prefs.get(PrefsKeys.wordTombstones);
    if (raw is! String) return const {};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const {};
    }
    if (decoded is! Map) return const {};
    return {
      for (final entry in decoded.entries)
        if (entry.key is String && entry.value is int)
          entry.key as String: entry.value as int,
    };
  }

  Future<void> saveTombstones(Map<String, int> tombstones) {
    return _prefs.setString(
      PrefsKeys.wordTombstones,
      jsonEncode(tombstones),
    );
  }

  Future<void> markDeleted(String id, DateTime at) {
    return saveTombstones({
      ...loadTombstones(),
      id: at.millisecondsSinceEpoch,
    });
  }

  Future<void> clearTombstone(String id) async {
    final tombstones = loadTombstones();
    if (!tombstones.containsKey(id)) return;
    await saveTombstones({...tombstones}..remove(id));
  }
}

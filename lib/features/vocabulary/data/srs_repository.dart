import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/prefs_keys.dart';
import '../domain/srs_card.dart';

class SrsRepository {
  SrsRepository(this._prefs);

  final SharedPreferences _prefs;

  List<SrsCard> load() {
    final raw = _prefs.get(PrefsKeys.srsCards);
    if (raw is! List) return const [];
    final cards = <SrsCard>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! String) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(item);
      } on FormatException {
        continue;
      }
      final card = SrsCard.fromJson(decoded);
      if (card == null || !seen.add(card.entry.id)) continue;
      cards.add(card);
    }
    return List.unmodifiable(cards);
  }

  Future<void> save(List<SrsCard> cards) {
    return _prefs.setStringList(PrefsKeys.srsCards, [
      for (final card in cards) jsonEncode(card.toJson()),
    ]);
  }
}

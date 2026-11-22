import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/prefs_keys.dart';
import '../domain/program_session.dart';

class ProgramRepository {
  ProgramRepository(this._prefs);

  final SharedPreferences _prefs;

  List<ProgramSession> load() {
    final raw = _prefs.get(PrefsKeys.programSessions);
    if (raw is! List) return const [];
    final byDay = <String, ProgramSession>{};
    for (final item in raw) {
      if (item is! String) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(item);
      } on FormatException {
        continue;
      }
      final session = ProgramSession.fromJson(decoded);
      if (session == null) continue;
      final key = formatProgramDay(session.date);
      final existing = byDay[key];
      if (existing == null || session.minutes > existing.minutes) {
        byDay[key] = session;
      }
    }
    final sessions = byDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(sessions);
  }

  Future<void> save(List<ProgramSession> sessions) {
    final sorted = [...sessions]..sort((a, b) => a.date.compareTo(b.date));
    return _prefs.setStringList(PrefsKeys.programSessions, [
      for (final session in sorted) jsonEncode(session.toJson()),
    ]);
  }
}

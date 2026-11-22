import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/prefs_keys.dart';
import '../domain/telemetry_event.dart';

class TelemetryRepository {
  TelemetryRepository(this._prefs);

  static const int maxEvents = 500;

  final SharedPreferences _prefs;

  List<TelemetryEvent> load() {
    final raw = _prefs.get(PrefsKeys.telemetryEvents);
    if (raw is! List) return const [];

    final events = <TelemetryEvent>[];
    for (final item in raw) {
      if (item is! String) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(item);
      } on FormatException {
        continue;
      }
      final event = TelemetryEvent.fromJson(decoded);
      if (event == null) continue;
      events.add(event);
    }
    if (events.length <= maxEvents) return List.unmodifiable(events);
    return List.unmodifiable(events.sublist(events.length - maxEvents));
  }

  Future<void> save(List<TelemetryEvent> events) {
    final start = events.length > maxEvents
        ? events.length - maxEvents
        : 0;
    return _prefs.setStringList(PrefsKeys.telemetryEvents, [
      for (final event in events.skip(start)) jsonEncode(event.toJson()),
    ]);
  }
}

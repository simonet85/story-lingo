import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/prefs_keys.dart';
import '../../../core/prefs/prefs_repository.dart';
import '../../program/data/program_repository.dart';
import '../../program/domain/program_session.dart';
import '../../reading/data/reading_progress_repository.dart';
import '../../vocabulary/data/saved_words_repository.dart';
import '../../vocabulary/data/srs_repository.dart';
import '../../vocabulary/domain/srs_card.dart';
import '../../vocabulary/domain/word_entry.dart';
import '../domain/sync_record.dart';

class SyncLocalStore {
  SyncLocalStore({
    required this.preferences,
    required this.prefs,
    required this.reading,
    required this.words,
    required this.srs,
    required this.program,
  });

  final SharedPreferences preferences;
  final PrefsRepository prefs;
  final ReadingProgressRepository reading;
  final SavedWordsRepository words;
  final SrsRepository srs;
  final ProgramRepository program;

  List<SyncRecord> collect() {
    return [
      ..._readingRecords(),
      ..._wordRecords(),
      ..._srsRecords(),
      ..._programRecords(),
      _profileRecord(),
    ];
  }

  List<SyncRecord> _readingRecords() {
    final records = <SyncRecord>[];
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(PrefsKeys.readingUpdatedPrefix)) continue;
      final suffix = key.substring(PrefsKeys.readingUpdatedPrefix.length);
      final separator = suffix.indexOf('.');
      if (separator <= 0 || separator == suffix.length - 1) continue;
      final bookId = suffix.substring(0, separator);
      final chapterId = suffix.substring(separator + 1);
      final state = reading.load(bookId, chapterId);
      records.add(
        SyncRecord(
          namespace: 'reading',
          id: '$bookId/$chapterId',
          updatedAt: state.updatedAt?.millisecondsSinceEpoch ?? 0,
          payload: {
            'paragraphId': state.paragraphId,
            'completed': state.completed,
          },
        ),
      );
    }
    return records;
  }

  List<SyncRecord> _wordRecords() {
    final records = [
      for (final saved in words.load())
        SyncRecord(
          namespace: 'words',
          id: saved.entry.id,
          updatedAt: saved.savedAt.millisecondsSinceEpoch,
          payload: saved.toJson(),
        ),
    ];
    for (final tombstone in words.loadTombstones().entries) {
      records.add(
        SyncRecord(
          namespace: 'words',
          id: tombstone.key,
          updatedAt: tombstone.value,
          deleted: true,
        ),
      );
    }
    return records;
  }

  List<SyncRecord> _srsRecords() {
    return [
      for (final card in srs.load())
        SyncRecord(
          namespace: 'srs',
          id: card.entry.id,
          updatedAt:
              (card.lastReviewedAt ?? card.introducedAt)
                  .millisecondsSinceEpoch,
          payload: card.toJson(),
        ),
    ];
  }

  List<SyncRecord> _programRecords() {
    return [
      for (final session in program.load())
        SyncRecord(
          namespace: 'program',
          id: formatProgramDay(session.date),
          updatedAt:
              session.updatedAt?.millisecondsSinceEpoch ??
              DateTime(
                session.date.year,
                session.date.month,
                session.date.day,
                12,
              ).millisecondsSinceEpoch,
          payload: session.toJson(),
        ),
    ];
  }

  SyncRecord _profileRecord() {
    return SyncRecord(
      namespace: 'prefs',
      id: 'profile',
      updatedAt: prefs.loadSettingsUpdatedMs() ?? 0,
      payload: prefs.exportProfile(),
    );
  }

  Future<void> apply(List<SyncRecord> records) async {
    if (records.isEmpty) return;
    final grouped = <String, List<SyncRecord>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.namespace, () => []).add(record);
    }

    await _applyReading(grouped['reading'] ?? const []);
    await _applyWords(grouped['words'] ?? const []);
    await _applySrs(grouped['srs'] ?? const []);
    await _applyProgram(grouped['program'] ?? const []);
    await _applyPrefs(grouped['prefs'] ?? const []);
  }

  Future<void> _applyReading(List<SyncRecord> records) async {
    for (final record in records) {
      final payload = record.payload;
      if (record.deleted || payload == null) continue;
      final separator = record.id.indexOf('/');
      if (separator <= 0 || separator == record.id.length - 1) continue;
      final rawParagraph = payload['paragraphId'];
      final completed = payload['completed'];
      await reading.applyRemote(
        record.id.substring(0, separator),
        record.id.substring(separator + 1),
        paragraphId: rawParagraph is String && rawParagraph.isNotEmpty
            ? rawParagraph
            : null,
        completed: completed == true,
        updatedAtMs: record.updatedAt,
      );
    }
  }

  Future<void> _applyWords(List<SyncRecord> records) async {
    final current = {
      for (final saved in words.load()) saved.entry.id: saved,
    };
    final tombstones = {...words.loadTombstones()};
    var wordsChanged = false;
    var tombstonesChanged = false;

    for (final record in records) {
      if (record.deleted) {
        if (current.remove(record.id) != null) wordsChanged = true;
        continue;
      }
      final payload = record.payload;
      if (payload == null) continue;
      final saved = SavedWord.fromJson(payload);
      if (saved == null || saved.entry.id != record.id) continue;
      current[record.id] = saved;
      wordsChanged = true;
      if (tombstones.remove(record.id) != null) tombstonesChanged = true;
    }

    if (wordsChanged) {
      final next = current.values.toList()
        ..sort((a, b) => a.savedAt.compareTo(b.savedAt));
      await words.save(next);
    }
    if (tombstonesChanged) {
      await words.saveTombstones(tombstones);
    }
  }

  Future<void> _applySrs(List<SyncRecord> records) async {
    final current = {
      for (final card in srs.load()) card.entry.id: card,
    };
    var changed = false;
    for (final record in records) {
      final payload = record.payload;
      if (record.deleted || payload == null) continue;
      final card = SrsCard.fromJson(payload);
      if (card == null || card.entry.id != record.id) continue;
      current[record.id] = card;
      changed = true;
    }
    if (changed) await srs.save(current.values.toList());
  }

  Future<void> _applyProgram(List<SyncRecord> records) async {
    final current = {
      for (final session in program.load())
        formatProgramDay(session.date): session,
    };
    var changed = false;
    for (final record in records) {
      final payload = record.payload;
      if (record.deleted || payload == null) continue;
      final session = ProgramSession.fromJson(payload);
      if (session == null) continue;
      if (formatProgramDay(session.date) != record.id) continue;
      current[record.id] = session;
      changed = true;
    }
    if (changed) await program.save(current.values.toList());
  }

  Future<void> _applyPrefs(List<SyncRecord> records) async {
    for (final record in records) {
      if (record.id != 'profile' || record.deleted) continue;
      final payload = record.payload;
      if (payload == null) continue;
      await prefs.applyProfile(payload, record.updatedAt);
    }
  }
}

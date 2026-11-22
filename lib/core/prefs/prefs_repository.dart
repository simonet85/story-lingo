import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/audio/domain/audio_speed.dart';
import '../../features/onboarding/domain/user_level.dart';
import '../../features/onboarding/domain/user_prefs.dart';
import '../../features/reading/domain/reading_mode.dart';
import 'prefs_keys.dart';

class PrefsRepository {
  PrefsRepository(this._prefs);

  final SharedPreferences _prefs;

  SharedPreferences get preferences => _prefs;

  static const int currentSchemaVersion = 1;

  Future<void> ensureSchemaVersion() async {
    if (_prefs.getInt(PrefsKeys.schemaVersion) != currentSchemaVersion) {
      await _prefs.setInt(PrefsKeys.schemaVersion, currentSchemaVersion);
    }
  }

  UserPrefs load() {
    final rawLevel = _prefs.get(PrefsKeys.userLevel);
    final rawCompleted = _prefs.get(PrefsKeys.onboardingCompleted);
    final rawThemeMode = _prefs.get(PrefsKeys.themeMode);

    return UserPrefs(
      level: UserLevel.fromId(rawLevel is String ? rawLevel : null),
      interests: _readInterests(),
      onboardingCompleted: rawCompleted is bool ? rawCompleted : false,
      themeMode: _themeModeFromId(rawThemeMode is String ? rawThemeMode : null),
    );
  }

  Future<void> save(UserPrefs prefs) async {
    await _prefs.setString(PrefsKeys.userLevel, prefs.level.id);
    await _prefs.setStringList(PrefsKeys.userInterests, prefs.interests);
    await _prefs.setBool(
      PrefsKeys.onboardingCompleted,
      prefs.onboardingCompleted,
    );
    await _prefs.setString(PrefsKeys.themeMode, _themeModeId(prefs.themeMode));
    await _touchSettings();
  }

  List<String> _readInterests() {
    final raw = _prefs.get(PrefsKeys.userInterests);
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  ReadingMode loadReadingMode() {
    final raw = _prefs.get(PrefsKeys.readingMode);
    return ReadingMode.fromId(raw is String ? raw : null);
  }

  Future<void> saveReadingMode(ReadingMode mode) async {
    await _prefs.setString(PrefsKeys.readingMode, mode.id);
    await _touchSettings();
  }

  double loadAudioSpeed() {
    final raw = _prefs.get(PrefsKeys.audioSpeed);
    if (raw is double && audioSpeedOptions.contains(raw)) return raw;
    return 1.0;
  }

  Future<void> saveAudioSpeed(double speed) async {
    if (!audioSpeedOptions.contains(speed)) return;
    await _prefs.setDouble(PrefsKeys.audioSpeed, speed);
    await _touchSettings();
  }

  Future<void> _touchSettings() {
    return _prefs.setInt(
      PrefsKeys.settingsUpdated,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  int? loadSettingsUpdatedMs() {
    final raw = _prefs.get(PrefsKeys.settingsUpdated);
    return raw is int ? raw : null;
  }

  Map<String, Object?> exportProfile() {
    final prefs = load();
    return {
      'level': prefs.level.id,
      'interests': prefs.interests,
      'onboardingCompleted': prefs.onboardingCompleted,
      'themeMode': _themeModeId(prefs.themeMode),
      'readingMode': loadReadingMode().id,
      'audioSpeed': loadAudioSpeed(),
    };
  }

  /// Applies a remote profile without bumping the local edit timestamp.
  Future<void> applyProfile(
    Map<String, Object?> payload,
    int updatedAtMs,
  ) async {
    final rawLevel = payload['level'];
    final rawInterests = payload['interests'];
    final rawCompleted = payload['onboardingCompleted'];
    final rawTheme = payload['themeMode'];
    final rawReadingMode = payload['readingMode'];
    final rawSpeed = payload['audioSpeed'];

    final level = UserLevel.fromId(rawLevel is String ? rawLevel : null);
    final interests = rawInterests is List
        ? rawInterests.whereType<String>().toList(growable: false)
        : const <String>[];
    final onboardingCompleted = rawCompleted is bool ? rawCompleted : false;
    final themeMode = _themeModeFromId(
      rawTheme is String ? rawTheme : null,
    );
    final readingMode = ReadingMode.fromId(
      rawReadingMode is String ? rawReadingMode : null,
    );
    final speed = rawSpeed is num && audioSpeedOptions.contains(rawSpeed.toDouble())
        ? rawSpeed.toDouble()
        : 1.0;

    await _prefs.setString(PrefsKeys.userLevel, level.id);
    await _prefs.setStringList(PrefsKeys.userInterests, interests);
    await _prefs.setBool(
      PrefsKeys.onboardingCompleted,
      onboardingCompleted,
    );
    await _prefs.setString(PrefsKeys.themeMode, _themeModeId(themeMode));
    await _prefs.setString(PrefsKeys.readingMode, readingMode.id);
    await _prefs.setDouble(PrefsKeys.audioSpeed, speed);
    await _prefs.setInt(PrefsKeys.settingsUpdated, updatedAtMs);
  }

  int loadSyncCursor() {
    final raw = _prefs.get(PrefsKeys.syncCursor);
    return raw is int && raw >= 0 ? raw : 0;
  }

  Future<void> saveSyncCursor(int revision) {
    return _prefs.setInt(PrefsKeys.syncCursor, revision);
  }

  DateTime? loadLastSyncAt() {
    final raw = _prefs.get(PrefsKeys.syncLastAt);
    return raw is int ? DateTime.fromMillisecondsSinceEpoch(raw) : null;
  }

  Future<void> saveLastSyncAt(DateTime at) {
    return _prefs.setInt(PrefsKeys.syncLastAt, at.millisecondsSinceEpoch);
  }

  static ThemeMode _themeModeFromId(String? id) => switch (id) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _themeModeId(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

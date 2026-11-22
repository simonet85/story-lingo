import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/features/onboarding/domain/user_level.dart';
import 'package:storylingo/features/onboarding/domain/user_prefs.dart';
import 'package:storylingo/features/reading/domain/reading_mode.dart';

Future<PrefsRepository> _repositoryWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final sharedPreferences = await SharedPreferences.getInstance();
  return PrefsRepository(sharedPreferences);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults are returned when no key is present', () async {
    final repository = await _repositoryWith({});
    final prefs = repository.load();

    expect(prefs.level, UserLevel.a2);
    expect(prefs.interests, isEmpty);
    expect(prefs.onboardingCompleted, isFalse);
    expect(prefs.themeMode, ThemeMode.system);
  });

  test('preferences round-trip through storage', () async {
    final repository = await _repositoryWith({});
    const saved = UserPrefs(
      level: UserLevel.b2,
      interests: ['gothic', 'mystery'],
      onboardingCompleted: true,
      themeMode: ThemeMode.dark,
    );

    await repository.save(saved);
    final loaded = repository.load();

    expect(loaded.level, UserLevel.b2);
    expect(loaded.interests, ['gothic', 'mystery']);
    expect(loaded.onboardingCompleted, isTrue);
    expect(loaded.themeMode, ThemeMode.dark);
  });

  test('corrupted values fall back to defaults without throwing', () async {
    final repository = await _repositoryWith({
      PrefsKeys.userLevel: 'zzz',
      PrefsKeys.onboardingCompleted: 'yes',
      PrefsKeys.userInterests: 'not-a-list',
      PrefsKeys.themeMode: 42,
    });

    final prefs = repository.load();

    expect(prefs.level, UserLevel.a2);
    expect(prefs.interests, isEmpty);
    expect(prefs.onboardingCompleted, isFalse);
    expect(prefs.themeMode, ThemeMode.system);
  });

  test('reading mode and audio speed round-trip', () async {
    final repository = await _repositoryWith({});

    expect(repository.loadReadingMode(), ReadingMode.read);
    expect(repository.loadAudioSpeed(), 1.0);

    await repository.saveReadingMode(ReadingMode.readListen);
    await repository.saveAudioSpeed(1.25);

    expect(repository.loadReadingMode(), ReadingMode.readListen);
    expect(repository.loadAudioSpeed(), 1.25);
  });

  test('unknown reading mode and speed fall back to defaults', () async {
    final repository = await _repositoryWith({
      PrefsKeys.readingMode: 'karaoke',
      PrefsKeys.audioSpeed: 2.0,
    });

    expect(repository.loadReadingMode(), ReadingMode.read);
    expect(repository.loadAudioSpeed(), 1.0);
  });

  test('schema version is written once', () async {
    final repository = await _repositoryWith({});
    await repository.ensureSchemaVersion();

    final sharedPreferences = await SharedPreferences.getInstance();
    expect(
      sharedPreferences.getInt(PrefsKeys.schemaVersion),
      PrefsRepository.currentSchemaVersion,
    );
  });
}

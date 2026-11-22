import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/prefs/prefs_repository.dart';
import 'core/prefs/user_prefs_provider.dart';
import 'features/program/data/program_repository.dart';
import 'features/program/presentation/program_provider.dart';
import 'features/reading/data/reading_progress_repository.dart';
import 'features/reading/presentation/reading_progress_provider.dart';
import 'features/telemetry/data/telemetry_repository.dart';
import 'features/telemetry/presentation/telemetry_provider.dart';
import 'features/vocabulary/data/saved_words_repository.dart';
import 'features/vocabulary/data/srs_repository.dart';
import 'features/vocabulary/presentation/saved_words_provider.dart';
import 'features/vocabulary/presentation/srs_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();
  final repository = PrefsRepository(sharedPreferences);
  await repository.ensureSchemaVersion();

  runApp(
    ProviderScope(
      overrides: [
        prefsRepositoryProvider.overrideWithValue(repository),
        readingProgressRepositoryProvider.overrideWithValue(
          ReadingProgressRepository(sharedPreferences),
        ),
        savedWordsRepositoryProvider.overrideWithValue(
          SavedWordsRepository(sharedPreferences),
        ),
        srsRepositoryProvider.overrideWithValue(
          SrsRepository(sharedPreferences),
        ),
        programRepositoryProvider.overrideWithValue(
          ProgramRepository(sharedPreferences),
        ),
        telemetryRepositoryProvider.overrideWithValue(
          TelemetryRepository(sharedPreferences),
        ),
      ],
      child: const StorylingoApp(),
    ),
  );
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/domain/user_level.dart';
import '../../features/onboarding/domain/user_prefs.dart';
import 'prefs_repository.dart';

final prefsRepositoryProvider = Provider<PrefsRepository>(
  (ref) => throw UnimplementedError(
    'prefsRepositoryProvider must be overridden at app start',
  ),
);

final userPrefsProvider = NotifierProvider<UserPrefsController, UserPrefs>(
  UserPrefsController.new,
);

class UserPrefsController extends Notifier<UserPrefs> {
  @override
  UserPrefs build() => ref.watch(prefsRepositoryProvider).load();

  Future<void> updateLevel(UserLevel level) =>
      _persist(state.copyWith(level: level));

  Future<void> updateThemeMode(ThemeMode mode) =>
      _persist(state.copyWith(themeMode: mode));

  Future<void> completeOnboarding({
    required UserLevel level,
    required List<String> interests,
  }) => _persist(
    state.copyWith(
      level: level,
      interests: interests,
      onboardingCompleted: true,
    ),
  );

  Future<void> _persist(UserPrefs next) async {
    await ref.read(prefsRepositoryProvider).save(next);
    state = next;
  }
}

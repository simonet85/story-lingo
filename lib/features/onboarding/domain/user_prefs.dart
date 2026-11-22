import 'package:material_ui/material_ui.dart';

import 'user_level.dart';

@immutable
class UserPrefs {
  const UserPrefs({
    this.level = UserLevel.a2,
    this.interests = const [],
    this.onboardingCompleted = false,
    this.themeMode = ThemeMode.system,
  });

  final UserLevel level;
  final List<String> interests;
  final bool onboardingCompleted;
  final ThemeMode themeMode;

  UserPrefs copyWith({
    UserLevel? level,
    List<String>? interests,
    bool? onboardingCompleted,
    ThemeMode? themeMode,
  }) => UserPrefs(
    level: level ?? this.level,
    interests: interests ?? this.interests,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    themeMode: themeMode ?? this.themeMode,
  );
}

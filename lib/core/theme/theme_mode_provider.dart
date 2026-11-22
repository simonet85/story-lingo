import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/user_prefs_provider.dart';

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(userPrefsProvider.select((prefs) => prefs.themeMode)),
);

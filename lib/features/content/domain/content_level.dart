import '../../onboarding/domain/user_level.dart';
import 'content_format_exception.dart';

UserLevel parseContentLevel(Object? value, String path) {
  if (value is String) {
    for (final level in UserLevel.values) {
      if (level.id == value) return level;
    }
  }
  throw ContentFormatException('$path: unknown CEFR level "$value".');
}

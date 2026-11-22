import 'content_format_exception.dart';

Map<String, dynamic> requireJsonObject(Object? value, String path) {
  if (value is! Map<String, dynamic>) {
    throw ContentFormatException('$path: expected a JSON object.');
  }
  return value;
}

List<dynamic> requireJsonList(Object? value, String path) {
  if (value is! List<dynamic>) {
    throw ContentFormatException('$path: expected a JSON array.');
  }
  return value;
}

String requireString(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ContentFormatException('$path.$key: expected a non-empty string.');
  }
  return value;
}

int requireInt(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! int) {
    throw ContentFormatException('$path.$key: expected an integer.');
  }
  return value;
}

int requireIntInRange(
  Map<String, dynamic> json,
  String key,
  String path, {
  required int min,
  required int max,
}) {
  final value = requireInt(json, key, path);
  if (value < min || value > max) {
    throw ContentFormatException(
      '$path.$key: expected a value between $min and $max, got $value.',
    );
  }
  return value;
}

int requireIntAtLeast(
  Map<String, dynamic> json,
  String key,
  String path,
  int min,
) {
  final value = requireInt(json, key, path);
  if (value < min) {
    throw ContentFormatException(
      '$path.$key: expected a value of at least $min, got $value.',
    );
  }
  return value;
}

String? optionalString(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw ContentFormatException('$path.$key: expected a non-empty string.');
  }
  return value;
}

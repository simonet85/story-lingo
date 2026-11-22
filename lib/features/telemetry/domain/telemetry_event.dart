import 'package:flutter/foundation.dart';

/// One local pilot event. Properties must stay JSON primitives.
@immutable
class TelemetryEvent {
  const TelemetryEvent({
    required this.name,
    required this.at,
    this.properties = const {},
  });

  final String name;
  final DateTime at;
  final Map<String, Object?> properties;

  Map<String, Object?> toJson() => {
    'name': name,
    'at': at.toUtc().toIso8601String(),
    ...properties,
  };

  static TelemetryEvent? fromJson(Object? source) {
    if (source is! Map) return null;
    final rawName = source['name'];
    final rawAt = source['at'];
    if (rawName is! String || rawName.trim().isEmpty || rawAt is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(rawAt);
    if (parsed == null) return null;

    final properties = <String, Object?>{};
    for (final entry in source.entries) {
      final key = entry.key;
      if (key is! String || key == 'name' || key == 'at') continue;
      final value = entry.value;
      if (value == null || value is String || value is num || value is bool) {
        properties[key] = value;
      }
    }

    return TelemetryEvent(
      name: rawName,
      at: parsed.toUtc(),
      properties: Map.unmodifiable(properties),
    );
  }
}

Map<String, Object?> sanitizeTelemetryProperties(
  Map<String, Object?> properties,
) {
  final sanitized = <String, Object?>{};
  for (final entry in properties.entries) {
    if (entry.key == 'name' || entry.key == 'at') continue;
    final value = entry.value;
    if (value == null || value is String || value is num || value is bool) {
      sanitized[entry.key] = value;
    }
  }
  return Map.unmodifiable(sanitized);
}

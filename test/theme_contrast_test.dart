import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/core/theme/app_theme.dart';

double _channel(int value) {
  final c = value / 255;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(int argb) {
  final color = argb & 0xFFFFFFFF;
  final r = (color >> 16) & 0xFF;
  final g = (color >> 8) & 0xFF;
  final b = color & 0xFF;
  return 0.2126 * _channel(r) + 0.7152 * _channel(g) + 0.0722 * _channel(b);
}

double _contrast(int a, int b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void _expectAa(
  String label,
  int foreground,
  int background, {
  double minimum = 4.5,
}) {
  final ratio = _contrast(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(minimum),
    reason: '$label : contraste ${ratio.toStringAsFixed(2)} < $minimum',
  );
  // ignore: avoid_print
  print('$label : ${ratio.toStringAsFixed(2)}:1');
}

void main() {
  test('les paires de couleurs principales atteignent AA', () {
    for (final (mode, theme) in [
      ('clair', AppTheme.light()),
      ('sombre', AppTheme.dark()),
    ]) {
      final scheme = theme.colorScheme;
      final cardColor = theme.cardTheme.color!.toARGB32();
      _expectAa(
        '$mode texte/surface',
        scheme.onSurface.toARGB32(),
        scheme.surface.toARGB32(),
      );
      _expectAa(
        '$mode texte secondaire/surface',
        scheme.onSurfaceVariant.toARGB32(),
        scheme.surface.toARGB32(),
      );
      _expectAa(
        '$mode texte secondaire/carte',
        scheme.onSurfaceVariant.toARGB32(),
        cardColor,
      );
      _expectAa(
        '$mode texte/primaire',
        scheme.onPrimary.toARGB32(),
        scheme.primary.toARGB32(),
      );
      _expectAa(
        '$mode texte/primaire doux',
        scheme.onPrimaryContainer.toARGB32(),
        scheme.primaryContainer.toARGB32(),
      );
      _expectAa(
        '$mode texte/accent doux',
        scheme.onSecondaryContainer.toARGB32(),
        scheme.secondaryContainer.toARGB32(),
      );
      _expectAa(
        '$mode primaire/surface',
        scheme.primary.toARGB32(),
        scheme.surface.toARGB32(),
      );
      _expectAa(
        '$mode bordure/surface',
        scheme.outline.toARGB32(),
        scheme.surface.toARGB32(),
        minimum: 3,
      );
    }
  });
}

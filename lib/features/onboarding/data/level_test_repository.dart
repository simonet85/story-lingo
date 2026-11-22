import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/level_test_question.dart';

class LevelTestRepository {
  LevelTestRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String assetPath = 'assets/onboarding/level_test_fr.json';

  final AssetBundle _bundle;

  Future<LevelTest> load() async {
    final raw = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Test de niveau invalide.');
    }
    return LevelTest.fromJson(decoded);
  }
}

final levelTestRepositoryProvider = Provider<LevelTestRepository>(
  (ref) => LevelTestRepository(),
);

final levelTestProvider = FutureProvider<LevelTest>(
  (ref) => ref.watch(levelTestRepositoryProvider).load(),
);

import 'user_level.dart';

enum LevelTestBand {
  a2(id: 'a2', points: 1),
  b1(id: 'b1', points: 2),
  b2(id: 'b2', points: 3);

  const LevelTestBand({required this.id, required this.points});

  final String id;
  final int points;

  UserLevel get userLevel => switch (this) {
    LevelTestBand.a2 => UserLevel.a2,
    LevelTestBand.b1 => UserLevel.b1,
    LevelTestBand.b2 => UserLevel.b2,
  };

  static LevelTestBand? tryParse(Object? raw) {
    for (final band in values) {
      if (band.id == raw) return band;
    }
    return null;
  }
}

class LevelTestQuestion {
  const LevelTestQuestion({
    required this.id,
    required this.band,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.explanationFr,
  });

  factory LevelTestQuestion.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final rawOptions = json['options'];
    final answerIndex = json['answerIndex'];
    final prompt = json['prompt'];
    final explanationFr = json['explanation_fr'];
    final band = LevelTestBand.tryParse(json['level']);

    if (id is! String ||
        prompt is! String ||
        rawOptions is! List ||
        answerIndex is! int ||
        explanationFr is! String ||
        band == null) {
      throw const FormatException('Question de test de niveau invalide.');
    }

    final options = rawOptions.whereType<String>().toList(growable: false);
    if (options.length != 4) {
      throw FormatException('La question $id doit avoir 4 options.');
    }
    if (answerIndex < 0 || answerIndex >= options.length) {
      throw FormatException('Réponse hors bornes pour la question $id.');
    }

    return LevelTestQuestion(
      id: id,
      band: band,
      prompt: prompt,
      options: options,
      answerIndex: answerIndex,
      explanationFr: explanationFr,
    );
  }

  final String id;
  final LevelTestBand band;
  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String explanationFr;
}

class LevelTest {
  LevelTest({
    required this.version,
    required this.instructions,
    required this.questions,
  }) {
    _validate();
  }

  factory LevelTest.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final instructions = json['instructions'];
    final rawQuestions = json['questions'];

    if (version is! int || instructions is! String || rawQuestions is! List) {
      throw const FormatException('Structure du test de niveau invalide.');
    }

    final questions = rawQuestions
        .map((raw) {
          if (raw is! Map) {
            throw const FormatException('Question de test de niveau invalide.');
          }
          return LevelTestQuestion.fromJson(Map<String, Object?>.from(raw));
        })
        .toList(growable: false);

    return LevelTest(
      version: version,
      instructions: instructions,
      questions: questions,
    );
  }

  final int version;
  final String instructions;
  final List<LevelTestQuestion> questions;

  void _validate() {
    if (questions.length != 10) {
      throw FormatException(
        'Le test doit contenir 10 questions, trouvé ${questions.length}.',
      );
    }

    final counts = {for (final band in LevelTestBand.values) band: 0};
    final ids = <String>{};
    for (final question in questions) {
      if (!ids.add(question.id)) {
        throw FormatException(
          'Identifiant de question dupliqué : ${question.id}.',
        );
      }
      counts[question.band] = counts[question.band]! + 1;
    }

    const expected = {
      LevelTestBand.a2: 4,
      LevelTestBand.b1: 3,
      LevelTestBand.b2: 3,
    };
    for (final entry in expected.entries) {
      if (counts[entry.key] != entry.value) {
        throw FormatException(
          'Répartition attendue 4 A2 / 3 B1 / 3 B2, reçue '
          '${counts[LevelTestBand.a2]} A2 / ${counts[LevelTestBand.b1]} B1 / '
          '${counts[LevelTestBand.b2]} B2.',
        );
      }
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/onboarding/domain/level_scoring.dart';
import 'package:storylingo/features/onboarding/domain/level_test_question.dart';
import 'package:storylingo/features/onboarding/domain/user_level.dart';

LevelTestQuestion _question(String id, LevelTestBand band) => LevelTestQuestion(
  id: id,
  band: band,
  prompt: 'Prompt ___',
  options: const ['a', 'b', 'c', 'd'],
  answerIndex: 0,
  explanationFr: '',
);

List<LevelTestQuestion> _questions() => [
  for (var i = 0; i < 4; i++) _question('a2-$i', LevelTestBand.a2),
  for (var i = 0; i < 3; i++) _question('b1-$i', LevelTestBand.b1),
  for (var i = 0; i < 3; i++) _question('b2-$i', LevelTestBand.b2),
];

void main() {
  group('levelForPoints', () {
    test('A2 below 8 points', () {
      expect(LevelScoring.levelForPoints(0), UserLevel.a2);
      expect(LevelScoring.levelForPoints(7), UserLevel.a2);
    });

    test('B1 from 8 to 12 points', () {
      expect(LevelScoring.levelForPoints(8), UserLevel.b1);
      expect(LevelScoring.levelForPoints(12), UserLevel.b1);
    });

    test('B2 from 13 points', () {
      expect(LevelScoring.levelForPoints(13), UserLevel.b2);
      expect(LevelScoring.levelForPoints(LevelScoring.maxPoints), UserLevel.b2);
    });
  });

  group('estimate', () {
    test('only A2 answers correct scores 4 points and stays A2', () {
      final questions = _questions();
      final answers = List<int?>.filled(10, 1);
      for (var i = 0; i < 4; i++) {
        answers[i] = 0;
      }

      expect(
        LevelScoring.estimate(questions: questions, answers: answers),
        UserLevel.a2,
      );
    });

    test('A2 and B1 answers correct score 10 points and land on B1', () {
      final questions = _questions();
      final answers = List<int?>.filled(10, 1);
      for (var i = 0; i < 7; i++) {
        answers[i] = 0;
      }

      expect(
        LevelScoring.estimate(questions: questions, answers: answers),
        UserLevel.b1,
      );
    });

    test('all answers correct score 19 points and land on B2', () {
      final answers = List<int?>.filled(10, 0);

      expect(
        LevelScoring.estimate(questions: _questions(), answers: answers),
        UserLevel.b2,
      );
    });

    test('no correct answer defaults to A2', () {
      final answers = List<int?>.filled(10, 3);

      expect(
        LevelScoring.estimate(questions: _questions(), answers: answers),
        UserLevel.a2,
      );
    });
  });
}

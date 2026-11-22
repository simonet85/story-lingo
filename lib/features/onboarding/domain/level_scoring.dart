import 'level_test_question.dart';
import 'user_level.dart';

abstract final class LevelScoring {
  static const int b1Threshold = 8;
  static const int b2Threshold = 13;
  static const int maxPoints = 19;

  static UserLevel levelForPoints(int points) {
    if (points >= b2Threshold) return UserLevel.b2;
    if (points >= b1Threshold) return UserLevel.b1;
    return UserLevel.a2;
  }

  static UserLevel estimate({
    required List<LevelTestQuestion> questions,
    required List<int?> answers,
  }) {
    var points = 0;
    for (
      var index = 0;
      index < questions.length && index < answers.length;
      index++
    ) {
      if (answers[index] == questions[index].answerIndex) {
        points += questions[index].band.points;
      }
    }
    return levelForPoints(points);
  }
}

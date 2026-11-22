import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/onboarding/data/level_test_repository.dart';
import 'package:storylingo/features/onboarding/domain/level_test_question.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('level test asset is complete and well formed', () async {
    final levelTest = await LevelTestRepository().load();

    expect(levelTest.questions, hasLength(10));
    expect(
      levelTest.questions.where((q) => q.band == LevelTestBand.a2),
      hasLength(4),
    );
    expect(
      levelTest.questions.where((q) => q.band == LevelTestBand.b1),
      hasLength(3),
    );
    expect(
      levelTest.questions.where((q) => q.band == LevelTestBand.b2),
      hasLength(3),
    );
    expect(levelTest.questions.map((q) => q.id).toSet(), hasLength(10));

    for (final question in levelTest.questions) {
      expect(question.options, hasLength(4));
      expect(question.answerIndex, inInclusiveRange(0, 3));
      expect(question.prompt, contains('___'));
      expect(question.explanationFr, isNotEmpty);
    }
  });
}

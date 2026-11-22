import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/user_prefs_provider.dart';
import '../data/level_test_repository.dart';
import '../domain/interest.dart';
import '../domain/level_scoring.dart';
import '../domain/level_test_question.dart';
import '../domain/user_level.dart';

enum OnboardingStep { welcome, levelTest, result, interests }

@immutable
class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.welcome,
    this.questionIndex = 0,
    this.answers = const [],
    this.interests = const {},
    this.level,
    this.loadError,
  });

  final OnboardingStep step;
  final int questionIndex;
  final List<int?> answers;
  final Set<String> interests;
  final UserLevel? level;
  final String? loadError;

  int? get currentAnswer =>
      questionIndex < answers.length ? answers[questionIndex] : null;

  OnboardingState copyWith({
    OnboardingStep? step,
    int? questionIndex,
    List<int?>? answers,
    Set<String>? interests,
    UserLevel? level,
    String? loadError,
  }) => OnboardingState(
    step: step ?? this.step,
    questionIndex: questionIndex ?? this.questionIndex,
    answers: answers ?? this.answers,
    interests: interests ?? this.interests,
    level: level ?? this.level,
    loadError: loadError ?? this.loadError,
  );
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  Future<void> begin() async {
    try {
      final test = await ref.read(levelTestProvider.future);
      state = OnboardingState(
        step: OnboardingStep.levelTest,
        answers: List<int?>.filled(test.questions.length, null),
      );
    } catch (_) {
      state = state.copyWith(
        loadError: 'Impossible de charger le test de niveau. Réessayez.',
      );
    }
  }

  void selectAnswer(int optionIndex) {
    if (state.answers.isEmpty) return;
    final answers = List<int?>.of(state.answers);
    answers[state.questionIndex] = optionIndex;
    state = state.copyWith(answers: answers);
  }

  void nextQuestion(List<LevelTestQuestion> questions) {
    if (state.questionIndex + 1 < questions.length) {
      state = state.copyWith(questionIndex: state.questionIndex + 1);
      return;
    }
    state = state.copyWith(
      step: OnboardingStep.result,
      level: LevelScoring.estimate(
        questions: questions,
        answers: state.answers,
      ),
    );
  }

  void goToInterests() {
    state = state.copyWith(step: OnboardingStep.interests);
  }

  void toggleInterest(String id) {
    final interests = {...state.interests};
    if (!interests.remove(id)) {
      interests.add(id);
    }
    state = state.copyWith(interests: interests);
  }

  Future<bool> complete() async {
    if (state.interests.length < 2) return false;
    try {
      await ref
          .read(userPrefsProvider.notifier)
          .completeOnboarding(
            level: state.level ?? UserLevel.a2,
            interests: Interest.orderedIds(state.interests),
          );
      return true;
    } catch (_) {
      return false;
    }
  }
}

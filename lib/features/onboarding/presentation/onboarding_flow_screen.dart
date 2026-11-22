import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../application/onboarding_controller.dart';
import '../data/level_test_repository.dart';
import '../domain/user_level.dart';
import 'interests_screen.dart';
import 'level_result_screen.dart';
import 'level_test_screen.dart';
import 'welcome_screen.dart';

class OnboardingFlowScreen extends ConsumerWidget {
  const OnboardingFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final levelTest = ref.watch(levelTestProvider);

    final Widget step = switch (state.step) {
      OnboardingStep.welcome => WelcomeScreen(
        error: state.loadError,
        onStart: controller.begin,
      ),
      OnboardingStep.levelTest => levelTest.when(
        data: (test) => LevelTestScreen(
          questions: test.questions,
          answers: state.answers,
          index: state.questionIndex,
          onSelect: controller.selectAnswer,
          onNext: () => controller.nextQuestion(test.questions),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _LevelTestLoadError(onRetry: controller.begin),
      ),
      OnboardingStep.result => LevelResultScreen(
        level: state.level ?? UserLevel.a2,
        onContinue: controller.goToInterests,
      ),
      OnboardingStep.interests => InterestsScreen(selected: state.interests),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.contentMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: step,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelTestLoadError extends StatelessWidget {
  const _LevelTestLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Impossible de charger le test de niveau.',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    );
  }
}

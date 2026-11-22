import 'program_progress.dart';

enum ProgramBadge { firstDay, streak3, streak7, halfway, complete, tenWords }

extension ProgramBadgeCopy on ProgramBadge {
  String get title => switch (this) {
    ProgramBadge.firstDay => 'Premier pas',
    ProgramBadge.streak3 => 'Série de 3 jours',
    ProgramBadge.streak7 => 'Semaine d’élan',
    ProgramBadge.halfway => 'Mi-parcours',
    ProgramBadge.complete => 'Les 28 jours',
    ProgramBadge.tenWords => 'Dix mots en révision',
  };

  String get description => switch (this) {
    ProgramBadge.firstDay => 'Terminer votre premier jour du programme.',
    ProgramBadge.streak3 => 'Trois jours d’affilée, bouclier inclus.',
    ProgramBadge.streak7 => 'Sept jours d’affilée, bouclier inclus.',
    ProgramBadge.halfway => 'Atteindre le jour 14 du parcours.',
    ProgramBadge.complete => 'Accomplir les 28 jours du programme.',
    ProgramBadge.tenWords => 'Avoir dix mots de votre lecture en révision.',
  };
}

class ProgramBadgeStatus {
  const ProgramBadgeStatus({required this.badge, required this.earned});

  final ProgramBadge badge;
  final bool earned;
}

List<ProgramBadgeStatus> evaluateProgramBadges({
  required ProgramProgress progress,
  required int vocabularyCards,
}) {
  bool earned(ProgramBadge badge) => switch (badge) {
    ProgramBadge.firstDay => progress.daysCompleted >= 1,
    ProgramBadge.streak3 => progress.bestStreak >= 3,
    ProgramBadge.streak7 => progress.bestStreak >= 7,
    ProgramBadge.halfway => progress.daysCompleted >= 14,
    ProgramBadge.complete => progress.daysCompleted >= programLength,
    ProgramBadge.tenWords => vocabularyCards >= 10,
  };

  return [
    for (final badge in ProgramBadge.values)
      ProgramBadgeStatus(badge: badge, earned: earned(badge)),
  ];
}

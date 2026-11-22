enum UserLevel {
  a2(
    id: 'a2',
    shortLabel: 'A2',
    label: 'A2 — Élémentaire',
    description:
        'Vous comprenez les phrases courantes et les histoires simples.',
  ),
  b1(
    id: 'b1',
    shortLabel: 'B1',
    label: 'B1 — Intermédiaire',
    description:
        'Vous suivez une intrigue et les idées principales d’un récit.',
  ),
  b2(
    id: 'b2',
    shortLabel: 'B2',
    label: 'B2 — Avancé',
    description: 'Vous lisez avec aisance des textes nuancés et des tournures idiomatiques.',
  );

  const UserLevel({
    required this.id,
    required this.shortLabel,
    required this.label,
    required this.description,
  });

  final String id;
  final String shortLabel;
  final String label;
  final String description;

  static UserLevel fromId(String? id) {
    for (final level in values) {
      if (level.id == id) return level;
    }
    return a2;
  }
}

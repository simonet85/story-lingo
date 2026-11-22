enum Interest {
  mystery(id: 'mystery', label: 'Policier & mystère'),
  adventure(id: 'adventure', label: 'Aventure'),
  gothic(id: 'gothic', label: 'Gothique & horreur'),
  fantasy(id: 'fantasy', label: 'Fantastique'),
  satire(id: 'satire', label: 'Humour & satire'),
  history(id: 'history', label: 'Histoire');

  const Interest({required this.id, required this.label});

  final String id;
  final String label;

  static List<String> orderedIds(Iterable<String> selectedIds) => [
    for (final interest in values)
      if (selectedIds.contains(interest.id)) interest.id,
  ];
}

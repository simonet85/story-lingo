import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'saved_words_provider.dart';

class WordListButton extends ConsumerWidget {
  const WordListButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(savedWordsProvider).length;
    return IconButton(
      tooltip: 'Ma liste de mots',
      onPressed: () => context.push('/words'),
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.bookmark_outline),
      ),
    );
  }
}

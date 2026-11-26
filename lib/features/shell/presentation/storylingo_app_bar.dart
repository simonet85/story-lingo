import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../vocabulary/presentation/word_list_button.dart';

class StorylingoAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const StorylingoAppBar({required this.title, super.key});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showSettings =
        MediaQuery.sizeOf(context).width < AppSizes.compactBreakpoint;
    return AppBar(
      title: Text(title),
      actions: [
        const WordListButton(),
        if (showSettings)
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
      ],
    );
  }
}

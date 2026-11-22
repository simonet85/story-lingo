import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../application/book_access_provider.dart';
import 'locked_book_screen.dart';

class BookAccessGate extends ConsumerWidget {
  const BookAccessGate({
    required this.bookId,
    required this.child,
    super.key,
  });

  final String bookId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(bookAccessProvider(bookId));
    return switch (access) {
      BookAccess.unknown => Scaffold(
        appBar: AppBar(title: const Text('Lecture')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      BookAccess.locked => LockedBookScreen(bookId: bookId),
      _ => child,
    };
  }
}

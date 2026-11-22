import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../content/data/content_repository.dart';
import '../../content/domain/content_offline_exception.dart';
import 'reading_screen.dart';

class BookEntryScreen extends ConsumerWidget {
  const BookEntryScreen({required this.bookId, super.key});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifest = ref.watch(bookManifestProvider(bookId));

    return switch (manifest) {
      AsyncValue(:final value?) => ReadingScreen(
        key: ValueKey('$bookId/${value.chapters.first.id}'),
        bookId: bookId,
        chapterId: value.chapters.first.id,
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('Lecture')),
        body: _BookError(
          onRetry: () => ref.invalidate(bookManifestProvider(bookId)),
          message: error is ContentOfflineException
              ? error.message
              : 'Impossible de charger ce livre.',
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Lecture')),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _BookError extends StatelessWidget {
  const _BookError({required this.onRetry, required this.message});

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

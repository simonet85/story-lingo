import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../content/data/content_repository.dart';

class LockedBookScreen extends ConsumerWidget {
  const LockedBookScreen({required this.bookId, super.key});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final books = ref.watch(catalogueProvider).value?.books ?? const [];
    String? title;
    for (final book in books) {
      if (book.id == bookId) {
        title = book.titleFr;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lecture')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 34,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Ce livre fait partie de l’abonnement',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    title == null
                        ? 'Votre abonnement débloque toute la bibliothèque, '
                              'y compris ce livre.'
                        : '« $title » rejoint la bibliothèque Storylingo. '
                              'Votre abonnement débloque tous les livres, '
                              'y compris celui-ci.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: () => context.push(
                      '/paywall?bookId=${Uri.encodeComponent(bookId)}',
                    ),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Voir les offres'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.go('/library'),
                    child: const Text('Retour à la bibliothèque'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

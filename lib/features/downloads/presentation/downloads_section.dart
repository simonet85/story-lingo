import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../application/download_providers.dart';
import '../data/download_platform.dart';
import '../domain/download_exception.dart';
import '../domain/installed_pack.dart';

class DownloadsSection extends ConsumerWidget {
  const DownloadsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(downloadPlatformProvider);
    if (platform == DownloadPlatform.other) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Téléchargements', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        if (platform == DownloadPlatform.web)
          Text(
            'Le téléchargement hors-ligne est disponible sur l’application '
            'mobile. Sur le web, les livres restent disponibles en streaming.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          const _DownloadsBody(),
      ],
    );
  }
}

class _DownloadsBody extends ConsumerWidget {
  const _DownloadsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final index = ref.watch(downloadIndexProvider);
    final value = index.value;
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (value.isEmpty) {
      return Text(
        'Aucun livre téléchargé. Utilisez le bouton Télécharger depuis la '
        'bibliothèque.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final packs = value.packs.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatBytes(value.totalBytes)} utilisés sur cet appareil',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final pack in packs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_done),
            title: Text(pack.title),
            subtitle: Text(
              'Version ${pack.packVersion} · ${formatBytes(pack.totalBytes)}',
            ),
            trailing: IconButton(
              tooltip: 'Supprimer ${pack.title}',
              onPressed: () => _confirmRemove(context, ref, pack),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    InstalledPack pack,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Supprimer ${pack.title} ?'),
        content: const Text(
          'Le livre restera disponible en streaming. Votre progression est '
          'conservée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(downloadRepositoryProvider).remove(pack.bookId);
      await ref.read(downloadIndexProvider.notifier).refresh();
      messenger.showSnackBar(
        const SnackBar(content: Text('Livre supprimé de l’appareil.')),
      );
    } on DownloadException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

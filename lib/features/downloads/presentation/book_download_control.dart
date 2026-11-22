import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../billing/application/book_access_provider.dart';
import '../application/download_providers.dart';
import '../data/download_platform.dart';
import '../domain/installed_pack.dart';

class BookDownloadControl extends ConsumerWidget {
  const BookDownloadControl({
    required this.bookId,
    required this.availableVersion,
    super.key,
  });

  final String bookId;
  final String availableVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(bookAccessProvider(bookId)) == BookAccess.locked) {
      return const SizedBox.shrink();
    }
    final platform = ref.watch(downloadPlatformProvider);
    if (platform == DownloadPlatform.other) return const SizedBox.shrink();
    if (platform == DownloadPlatform.web) {
      return const _DownloadNotice(
        icon: Icons.phone_android,
        message:
            'Téléchargement hors-ligne disponible sur l’application '
            'mobile.',
      );
    }
    if (ref.watch(apiBaseUrlProvider).isEmpty) {
      return const _DownloadNotice(
        icon: Icons.cloud_off_outlined,
        message:
            'Téléchargement indisponible : aucun serveur de contenu '
            'n’est configuré.',
      );
    }

    final theme = Theme.of(context);
    final index = ref.watch(downloadIndexProvider);
    final installed = ref.watch(installedPackProvider(bookId));
    final job = ref.watch(downloadJobProvider(bookId));

    if (index.isLoading && !index.hasValue) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: LinearProgressIndicator(
          minHeight: 2,
          semanticsLabel: 'Vérification des téléchargements',
        ),
      );
    }

    if (job != null && job.isActive) {
      final cancelling = job.status == DownloadJobStatus.cancelling;
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: cancelling
                  ? 'Annulation du téléchargement'
                  : 'Téléchargement ${job.percent} pour cent',
              child: LinearProgressIndicator(
                value: job.totalBytes > 0 ? job.progress : null,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    cancelling
                        ? 'Annulation…'
                        : job.totalBytes > 0
                        ? 'Téléchargement… ${job.percent} %'
                        : 'Préparation du téléchargement…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: cancelling
                      ? null
                      : () => ref
                            .read(downloadJobsProvider.notifier)
                            .cancel(bookId),
                  child: const Text('Annuler'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (job?.status == DownloadJobStatus.error) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                job!.error ?? 'Téléchargement impossible.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(downloadJobsProvider.notifier).start(bookId),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (installed != null) {
      final updateAvailable = installed.hasUpdate(availableVersion);
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  updateAvailable
                      ? Icons.download_for_offline_outlined
                      : Icons.download_done,
                  size: 18,
                  color: updateAvailable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Téléchargé · ${formatBytes(installed.totalBytes)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (updateAvailable)
                  Chip(
                    label: const Text('Mise à jour'),
                    visualDensity: VisualDensity.compact,
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    side: BorderSide.none,
                  ),
              ],
            ),
            if (updateAvailable) ...[
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(downloadJobsProvider.notifier).start(bookId),
                icon: const Icon(Icons.system_update_alt),
                label: const Text('Mettre à jour'),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: OutlinedButton.icon(
        onPressed: () => ref.read(downloadJobsProvider.notifier).start(bookId),
        icon: const Icon(Icons.download_outlined),
        label: const Text('Télécharger'),
      ),
    );
  }
}

class _DownloadNotice extends StatelessWidget {
  const _DownloadNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

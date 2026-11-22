import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/user_prefs_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../account/domain/auth_session.dart';
import '../../account/presentation/auth_provider.dart';
import '../../billing/presentation/subscription_section.dart';
import '../../content/data/content_repository.dart';
import '../../downloads/presentation/downloads_section.dart';
import '../../onboarding/domain/user_level.dart';
import '../../program/presentation/program_provider.dart';
import '../../sync/presentation/sync_provider.dart';
import '../../telemetry/domain/telemetry_export.dart';
import '../../telemetry/presentation/telemetry_provider.dart';
import '../../vocabulary/presentation/srs_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(userPrefsProvider);
    final prefsController = ref.read(userPrefsProvider.notifier);
    final events = ref.watch(telemetryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _AccountSection(),
          const Divider(height: AppSpacing.xxl),
          const SubscriptionSection(),
          const Divider(height: AppSpacing.xxl),
          Text('Votre niveau', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cette estimation sert à choisir vos premiers livres. Elle reste '
            'modifiable à tout moment.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<UserLevel>(
            segments: [
              for (final level in UserLevel.values)
                ButtonSegment(value: level, label: Text(level.shortLabel)),
            ],
            selected: {prefs.level},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                prefsController.updateLevel(selection.first),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(prefs.level.label, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(prefs.level.description, style: theme.textTheme.bodyMedium),
          const Divider(height: AppSpacing.xxl),
          Text('Apparence', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Choisissez la luminosité de l’application.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Système')),
              ButtonSegment(value: ThemeMode.light, label: Text('Clair')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Sombre')),
            ],
            selected: {prefs.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                prefsController.updateThemeMode(selection.first),
          ),
          const DownloadsSection(),
          const Divider(height: AppSpacing.xxl),
          Text('Données de test', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Les événements de votre parcours restent sur cet appareil. '
            'Copiez l’export JSON pour le partager avec l’équipe du pilote.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            events.length == 1
                ? '1 événement enregistré'
                : '${events.length} événements enregistrés',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _copyExport(context, ref),
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copier l’export JSON'),
            ),
          ),
          TextButton.icon(
            onPressed: events.isEmpty
                ? null
                : () => _confirmClear(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Effacer la télémétrie'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyExport(BuildContext context, WidgetRef ref) async {
    final book = ref.read(pilotBookProvider).value;
    final payload = encodeTelemetryExport(
      events: ref.read(telemetryProvider),
      sessions: ref.read(programProvider),
      progress: ref.read(programProgressProvider),
      cards: ref.read(srsProvider),
      prefs: ref.read(userPrefsProvider),
      packVersion: book?.packVersion ?? 'unknown',
      chapterCount: book?.chapters.length ?? 0,
      exportedAt: ref.read(nowProvider)(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export copié dans le presse-papiers.')),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Effacer la télémétrie ?'),
        content: const Text(
          'Les événements locaux seront supprimés. Votre progression, vos '
          'mots et le programme ne changent pas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(telemetryProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Télémétrie effacée.')),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final sync = ref.watch(syncControllerProvider);
    final session = auth.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Compte', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (auth.status == AuthStatus.restoring) ...[
          Row(
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Restauration de la session…',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ] else if (session != null) ...[
          Text(
            session.email ?? 'Compte connecté',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            authModeLabel(session.mode),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            sync.lastSyncedAt == null
                ? 'Jamais synchronisé'
                : 'Dernière synchronisation : ${_formatSyncDate(sync.lastSyncedAt!)}',
            style: theme.textTheme.bodyMedium,
          ),
          if (sync.hasError) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              sync.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: sync.isBusy
                  ? null
                  : () => _syncNow(context, ref),
              icon: sync.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                sync.isBusy
                    ? 'Synchronisation…'
                    : 'Synchroniser maintenant',
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ] else ...[
          Text(
            'Synchronisez votre progression, vos mots et vos révisions sur '
            'tous vos appareils. Vos données restent disponibles hors-ligne.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (auth.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              auth.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/account'),
              icon: const Icon(Icons.login),
              label: const Text('Se connecter'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final succeeded = await ref
        .read(syncControllerProvider.notifier)
        .syncNow();
    if (!context.mounted || !succeeded) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Synchronisation terminée.')),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vos données locales restent sur cet appareil et la lecture '
          'hors-ligne continue de fonctionner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authControllerProvider.notifier).signOut();
    messenger.showSnackBar(
      const SnackBar(content: Text('Déconnecté. Données locales conservées.')),
    );
  }

  String _formatSyncDate(DateTime value) {
    final local = value.toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} à '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

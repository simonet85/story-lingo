import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../account/presentation/auth_provider.dart';
import '../application/billing_providers.dart';
import '../application/entitlement_provider.dart';
import '../domain/billing_entitlement.dart';

class SubscriptionSection extends ConsumerWidget {
  const SubscriptionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final state = ref.watch(entitlementControllerProvider);
    final active = ref.watch(isEntitledProvider);
    final now = ref.watch(billingNowProvider)();
    final expiry = state.expiresAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Abonnement', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (active) ...[
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Storylingo Pro', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            expiry == null || !expiry.isAfter(now)
                ? 'Votre abonnement est actif.'
                : 'Actif jusqu’au ${_formatDate(expiry)}.',
            style: theme.textTheme.bodyMedium,
          ),
          if (state.error != null) ..._error(theme, state.error!),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: state.busy ? null : () => _restore(context, ref),
            icon: const Icon(Icons.restore),
            label: const Text('Restaurer mes achats'),
          ),
        ] else ...[
          Text(
            'Toute la bibliothèque, sans limite : les livres inclus dans '
            'l’abonnement et les nouveaux titres.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (state.error != null) ..._error(theme, state.error!),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/paywall'),
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('Découvrir l’abonnement'),
            ),
          ),
          TextButton.icon(
            onPressed: state.busy ? null : () => _restore(context, ref),
            icon: const Icon(Icons.restore),
            label: const Text('Restaurer mes achats'),
          ),
        ],
        if (!auth.isSignedIn) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Connectez-vous pour retrouver votre abonnement sur tous vos '
            'appareils.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (state.busy) ...[
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(
            minHeight: 2,
            semanticsLabel: 'Vérification de l’abonnement',
          ),
        ],
      ],
    );
  }

  List<Widget> _error(ThemeData theme, String message) => [
    const SizedBox(height: AppSpacing.sm),
    Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.error,
      ),
    ),
  ];

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final entitlement = await ref
          .read(entitlementControllerProvider.notifier)
          .restore();
      if (!context.mounted) return;
      final now = ref.read(billingNowProvider)();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            entitlement.isActiveAt(now)
                ? 'Achats restaurés.'
                : 'Aucun achat à restaurer.',
          ),
        ),
      );
    } on BillingException catch (failure) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } on Exception {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Restauration impossible pour le moment.'),
        ),
      );
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

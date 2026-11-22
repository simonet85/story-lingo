import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../application/billing_providers.dart';
import '../application/entitlement_provider.dart';
import '../domain/billing_entitlement.dart';
import '../domain/billing_offer.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({this.bookId, super.key});

  final String? bookId;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  late Future<List<BillingOffer>> _offers;
  BillingOfferKind _selectedKind = BillingOfferKind.yearly;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _offers = ref.read(billingGatewayProvider).loadOffers();
    Future<void>.microtask(
      () => ref
          .read(entitlementControllerProvider.notifier)
          .refresh(silent: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gateway = ref.watch(billingGatewayProvider);
    final state = ref.watch(entitlementControllerProvider);
    final error = _error ?? state.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Toute la bibliothèque, sans limite',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Un seul abonnement pour lire tous les livres Storylingo, '
                  'au rythme qui vous convient.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                const _Benefit(
                  icon: Icons.menu_book_outlined,
                  text: 'La bibliothèque complète, y compris les livres '
                      'rares et les grands classiques.',
                ),
                const _Benefit(
                  icon: Icons.new_releases_outlined,
                  text: 'Les nouveaux livres dès leur publication.',
                ),
                const _Benefit(
                  icon: Icons.sync_outlined,
                  text: 'Votre progression, vos mots et vos révisions '
                      'synchronisés.',
                ),
                const _Benefit(
                  icon: Icons.download_for_offline_outlined,
                  text: 'La lecture hors ligne, où que vous soyez.',
                ),
                if (gateway.isDemo) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadii.cardBorder,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Mode démo : l’achat est simulé sur cet appareil.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FutureBuilder<List<BillingOffer>>(
                  future: _offers,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
                      return Column(
                        children: [
                          Text(
                            'Les offres ne sont pas disponibles pour le '
                            'moment.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                            onPressed: _reloadOffers,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      );
                    }
                    final offers = snapshot.data!;
                    final selected = _selectedOffer(offers);
                    return Column(
                      children: [
                        for (final offer in offers) ...[
                          _OfferCard(
                            offer: offer,
                            selected: offer.kind == selected.kind,
                            onTap: _busy
                                ? null
                                : () => setState(
                                    () => _selectedKind = offer.kind,
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          height: AppSizes.primaryActionHeight,
                          child: FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _purchase(selected),
                            icon: _busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_open),
                            label: Text(
                              _busy
                                  ? 'Achat en cours…'
                                  : 'Choisir cet abonnement',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    error,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _notice!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _busy ? null : _restore,
                  child: const Text('Restaurer mes achats'),
                ),
                TextButton(
                  onPressed: _busy ? null : _later,
                  child: const Text('Plus tard'),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'L’abonnement se renouvelle automatiquement. Vous pouvez '
                  'le résilier à tout moment depuis votre compte.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BillingOffer _selectedOffer(List<BillingOffer> offers) {
    for (final offer in offers) {
      if (offer.kind == _selectedKind) return offer;
    }
    return offers.first;
  }

  void _reloadOffers() {
    setState(() {
      _error = null;
      _offers = ref.read(billingGatewayProvider).loadOffers();
    });
  }

  Future<void> _purchase(BillingOffer offer) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final entitlement = await ref
          .read(entitlementControllerProvider.notifier)
          .purchase(offer);
      if (!mounted) return;
      final now = ref.read(billingNowProvider)();
      if (!entitlement.isActiveAt(now)) {
        setState(() {
          _busy = false;
          _error = 'L’abonnement n’est pas encore actif. Réessayez dans un '
              'instant.';
        });
        return;
      }
      _finish('Abonnement actif. Bonne lecture !');
    } on BillingException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Achat impossible pour le moment. Réessayez plus tard.';
      });
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final entitlement = await ref
          .read(entitlementControllerProvider.notifier)
          .restore();
      if (!mounted) return;
      final now = ref.read(billingNowProvider)();
      if (entitlement.isActiveAt(now)) {
        _finish('Achats restaurés. Bonne lecture !');
        return;
      }
      setState(() {
        _busy = false;
        _notice = 'Aucun achat à restaurer sur ce compte.';
      });
    } on BillingException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Restauration impossible pour le moment.';
      });
    }
  }

  void _finish(String message) {
    final messenger = ScaffoldMessenger.of(context);
    final bookId = widget.bookId;
    if (bookId != null) {
      context.pushReplacement('/read/$bookId');
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/library');
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _later() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/library');
    }
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final BillingOffer offer;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.cardBorder,
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(offer.titleFr, style: theme.textTheme.titleMedium),
                        if (offer.badgeFr != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              offer.badgeFr!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offer.periodLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(offer.priceLabel, style: theme.textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

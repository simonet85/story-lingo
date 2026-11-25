import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_fusion/money_fusion.dart';

import '../../../core/theme/app_tokens.dart';
import '../../account/presentation/auth_provider.dart';
import '../application/mobile_money_flow.dart';
import '../application/mobile_money_providers.dart';
import '../data/mobile_money_api.dart';
import '../domain/mobile_money_product.dart';

class MobileMoneyScreen extends ConsumerStatefulWidget {
  const MobileMoneyScreen({required this.productId, super.key});

  final String productId;

  @override
  ConsumerState<MobileMoneyScreen> createState() => _MobileMoneyScreenState();
}

class _MobileMoneyScreenState extends ConsumerState<MobileMoneyScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  Future<MobileMoneyProduct?>? _product;
  bool _busy = false;
  bool _confirming = false;
  bool _done = false;
  String? _error;
  String? _notice;
  ProviderSubscription<PendingMobileMoneyState>? _pendingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pendingSubscription = ref.listenManual(pendingMobileMoneyProvider, (
      previous,
      next,
    ) {
      if (next.phase != PendingMobileMoneyPhase.active) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent ?? false) _finish();
      });
    });
    _product = ref.read(mobileMoneyFlowProvider).loadProduct(widget.productId);
  }

  @override
  void dispose() {
    _pendingSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(pendingMobileMoneyProvider.notifier).checkNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = ref.watch(authControllerProvider).isSignedIn;
    final available = ref.watch(mobileMoneyAvailableProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement mobile money')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.contentMaxWidth,
            ),
            child: !available
                ? _unavailable(theme)
                : FutureBuilder<MobileMoneyProduct?>(
                    future: _product,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final product = snapshot.data;
                      if (snapshot.hasError || product == null) {
                        return _productError(theme);
                      }
                      return _form(theme, product, signedIn);
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _unavailable(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Le paiement mobile money n’est pas disponible sur cet appareil.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _productError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Les offres ne sont pas disponibles pour le moment.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () {
              setState(() {
                _product = ref
                    .read(mobileMoneyFlowProvider)
                    .loadProduct(widget.productId);
              });
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _form(ThemeData theme, MobileMoneyProduct product, bool signedIn) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_android_outlined,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Abonnement ${product.titleFr.toLowerCase()}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.priceLabel} ${product.periodLabel}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Vous serez redirigé vers la page de paiement MoneyFusion. '
            'L’abonnement s’active dès confirmation du paiement.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!signedIn) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppRadii.cardBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connectez-vous pour payer par mobile money.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/account'),
                    icon: const Icon(Icons.login),
                    label: const Text('Se connecter'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _phone,
            enabled: signedIn && !_busy,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              hintText: '01010101',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            validator: _validatePhone,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _name,
            enabled: signedIn && !_busy,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Nom du titulaire',
              hintText: 'John Doe',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: _validateName,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: AppSizes.primaryActionHeight,
            child: FilledButton.icon(
              onPressed: signedIn && !_busy ? _submit : null,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.phone_iphone),
              label: Text(
                _confirming
                    ? 'Confirmation du paiement…'
                    : 'Payer ${product.priceLabel}',
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
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
        ],
      ),
    );
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Indiquez le numéro de téléphone.';
    if (phone.length < 8) return 'Numéro trop court.';
    if (!RegExp(r'^[0-9+ ]+$').hasMatch(phone)) return 'Numéro invalide.';
    return null;
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Indiquez le nom du titulaire.';
    if (name.length > 80) return 'Nom trop long.';
    return null;
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _confirming = false;
      _error = null;
      _notice = null;
    });
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .ensureSession();
      if (!mounted) return;
      if (session == null) {
        setState(() {
          _busy = false;
          _error = 'Connectez-vous pour payer.';
        });
        return;
      }
      final flow = ref.read(mobileMoneyFlowProvider);
      final request = await flow.start(
        accessToken: session.accessToken,
        productId: widget.productId,
        phone: _phone.text.trim(),
        name: _name.text.trim(),
      );
      if (!mounted) return;
      final pending = ref.read(pendingMobileMoneyProvider.notifier);
      pending.stop();
      if (!flow.isEntitled()) {
        pending.start();
      }
      final launcher = ref.read(moneyFusionCheckoutLauncherProvider);
      final result = await launcher(
        context,
        request: request,
        returnUrl: flow.returnUrl,
      );
      if (!mounted) return;
      await _handleResult(result, flow);
    } on MobileMoneyException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _confirming = false;
        _error = failure.message;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _confirming = false;
        _error = 'Paiement impossible pour le moment. Réessayez.';
      });
    }
  }

  Future<void> _handleResult(
    PaymentResult? result,
    MobileMoneyFlow flow,
  ) async {
    if (ref.read(pendingMobileMoneyProvider).phase ==
        PendingMobileMoneyPhase.active) {
      _finish();
      return;
    }
    if (result == null) {
      setState(() => _busy = false);
      return;
    }
    if (result is PaymentCancelled) {
      ref.read(pendingMobileMoneyProvider.notifier).stop();
      setState(() {
        _busy = false;
        _confirming = false;
        _notice = 'Paiement annulé.';
      });
      return;
    }
    if (result is PaymentError) {
      ref.read(pendingMobileMoneyProvider.notifier).start();
      setState(() {
        _busy = false;
        _confirming = false;
        _error = result.error.message;
        _notice =
            'La confirmation du paiement continue en arrière-plan. '
            'L’abonnement s’activera automatiquement dès validation.';
      });
      return;
    }
    if (result is! PaymentCompleted) return;
    switch (result.status) {
      case PaymentStatus.failure:
      case PaymentStatus.noPaid:
        ref.read(pendingMobileMoneyProvider.notifier).stop();
        setState(() {
          _busy = false;
          _confirming = false;
          _error = 'Paiement refusé ou annulé.';
        });
      case PaymentStatus.paid:
      case PaymentStatus.pending:
        ref.read(pendingMobileMoneyProvider.notifier).start();
        setState(() => _confirming = true);
        final active = await flow.confirm();
        if (!mounted) return;
        if (active) {
          _finish();
        } else {
          setState(() {
            _busy = false;
            _confirming = false;
            _notice =
                'Paiement en attente de confirmation. L’abonnement '
                's’activera automatiquement dès validation.';
          });
        }
    }
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    ref.read(pendingMobileMoneyProvider.notifier).stop();
    final messenger = ScaffoldMessenger.of(context);
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) {
      Navigator.of(context).pop();
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Abonnement actif. Bonne lecture !')),
    );
  }
}

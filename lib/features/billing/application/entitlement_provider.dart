import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../core/prefs/prefs_keys.dart';
import '../../../core/prefs/user_prefs_provider.dart';
import '../../account/presentation/auth_provider.dart';
import '../data/entitlements_api.dart';
import '../domain/billing_entitlement.dart';
import '../domain/billing_offer.dart';
import 'billing_providers.dart';

final entitlementsApiProvider = Provider<EntitlementsApi>((ref) {
  return EntitlementsApi(baseUrl: ref.watch(apiBaseUrlProvider));
});

class EntitlementState {
  const EntitlementState({
    this.gateway,
    this.server,
    this.busy = false,
    this.error,
    this.loaded = false,
  });

  final BillingEntitlement? gateway;
  final BillingEntitlement? server;
  final bool busy;
  final String? error;
  final bool loaded;

  bool isActiveAt(DateTime now) =>
      (gateway?.isActiveAt(now) ?? false) ||
      (server?.isActiveAt(now) ?? false);

  DateTime? get expiresAt {
    final gatewayExpiry = gateway?.expiresAt;
    final serverExpiry = server?.expiresAt;
    if (gatewayExpiry == null) return serverExpiry;
    if (serverExpiry == null) return gatewayExpiry;
    return gatewayExpiry.isAfter(serverExpiry) ? gatewayExpiry : serverExpiry;
  }
}

final entitlementControllerProvider =
    NotifierProvider<EntitlementController, EntitlementState>(
      EntitlementController.new,
    );

final isEntitledProvider = Provider<bool>((ref) {
  final state = ref.watch(entitlementControllerProvider);
  return state.isActiveAt(ref.watch(billingNowProvider)());
});

class EntitlementController extends Notifier<EntitlementState> {
  bool _refreshQueued = false;
  int _generation = 0;

  @override
  EntitlementState build() {
    final server = _readCache();
    Future<void>.microtask(() => refresh(silent: true));
    return EntitlementState(server: server);
  }

  Future<void> linkAccount(String userId) async {
    final gateway = ref.read(billingGatewayProvider);
    try {
      await gateway.configure();
      await gateway.logIn(userId);
    } on Exception {
      // A billing outage must never block signing in; refresh keeps local data.
    }
    await refresh(silent: true);
  }

  Future<void> unlinkAccount() async {
    try {
      await ref.read(billingGatewayProvider).logOut();
    } on Exception {
      // Local entitlement data is cleared below regardless.
    }
    await _clearCache();
    state = EntitlementState(
      gateway: state.gateway,
      busy: state.busy,
      loaded: state.loaded,
    );
    await refresh(silent: true);
  }

  Future<void> refresh({bool silent = false}) async {
    if (state.busy) {
      _refreshQueued = true;
      return;
    }
    final generation = ++_generation;
    final previous = state;
    state = EntitlementState(
      gateway: previous.gateway,
      server: previous.server,
      busy: true,
      error: silent ? previous.error : null,
      loaded: previous.loaded,
    );

    final gateway = ref.read(billingGatewayProvider);
    BillingEntitlement? gatewayEntitlement;
    String? error;
    try {
      await gateway.configure();
      gatewayEntitlement = await gateway.refresh();
    } on BillingException catch (failure) {
      error = failure.message;
    } on Exception {
      error = 'Impossible de vérifier l’abonnement.';
    }

    var server = previous.server;
    final auth = ref.read(authControllerProvider);
    if (auth.isSignedIn) {
      try {
        final session = await ref
            .read(authControllerProvider.notifier)
            .ensureSession();
        if (session != null) {
          server = await ref
              .read(entitlementsApiProvider)
              .fetch(token: session.accessToken);
          await _writeCache(server);
        }
      } on EntitlementsException catch (failure) {
        if (failure.unauthorized) {
          server = null;
          gatewayEntitlement = null;
          await _clearCache();
          unawaited(ref.read(authControllerProvider.notifier).signOut());
        }
        error ??= failure.message;
      } on Exception {
        error ??= 'Impossible de vérifier l’abonnement.';
      }
    }

    if (!ref.mounted) return;
    if (generation != _generation) return;
    state = EntitlementState(
      gateway: gatewayEntitlement ?? previous.gateway,
      server: server,
      busy: false,
      error: error,
      loaded: true,
    );

    if (_refreshQueued) {
      _refreshQueued = false;
      unawaited(refresh(silent: true));
    }
  }

  Future<BillingEntitlement> purchase(BillingOffer offer) async {
    _generation++;
    state = EntitlementState(
      gateway: state.gateway,
      server: state.server,
      busy: true,
      loaded: state.loaded,
    );
    try {
      final entitlement = await ref
          .read(billingGatewayProvider)
          .purchase(offer);
      state = EntitlementState(
        gateway: entitlement,
        server: state.server,
        loaded: true,
      );
      unawaited(refresh(silent: true));
      return entitlement;
    } on BillingException catch (failure) {
      state = EntitlementState(
        gateway: state.gateway,
        server: state.server,
        error: failure.message,
        loaded: state.loaded,
      );
      rethrow;
    } on Exception {
      const message = 'Achat impossible pour le moment. Réessayez plus tard.';
      state = EntitlementState(
        gateway: state.gateway,
        server: state.server,
        error: message,
        loaded: state.loaded,
      );
      throw const BillingException(message);
    }
  }

  Future<BillingEntitlement> restore() async {
    _generation++;
    state = EntitlementState(
      gateway: state.gateway,
      server: state.server,
      busy: true,
      loaded: state.loaded,
    );
    try {
      final entitlement = await ref.read(billingGatewayProvider).restore();
      state = EntitlementState(
        gateway: entitlement,
        server: state.server,
        loaded: true,
      );
      unawaited(refresh(silent: true));
      return entitlement;
    } on BillingException catch (failure) {
      state = EntitlementState(
        gateway: state.gateway,
        server: state.server,
        error: failure.message,
        loaded: state.loaded,
      );
      rethrow;
    } on Exception {
      const message = 'Restauration impossible pour le moment.';
      state = EntitlementState(
        gateway: state.gateway,
        server: state.server,
        error: message,
        loaded: state.loaded,
      );
      throw const BillingException(message);
    }
  }

  BillingEntitlement? _readCache() {
    final raw = ref
        .read(prefsRepositoryProvider)
        .preferences
        .getString(PrefsKeys.entitlementCache);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) {
        return BillingEntitlement.fromJson(value);
      }
      if (value is Map) {
        return BillingEntitlement.fromJson(Map<String, dynamic>.from(value));
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<void> _writeCache(BillingEntitlement entitlement) {
    return ref
        .read(prefsRepositoryProvider)
        .preferences
        .setString(
          PrefsKeys.entitlementCache,
          jsonEncode(entitlement.toJson()),
        );
  }

  Future<void> _clearCache() {
    return ref
        .read(prefsRepositoryProvider)
        .preferences
        .remove(PrefsKeys.entitlementCache);
  }
}

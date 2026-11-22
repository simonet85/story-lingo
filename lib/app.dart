import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/prefs/user_prefs_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/account/presentation/auth_provider.dart';
import 'features/billing/application/entitlement_provider.dart';
import 'features/sync/presentation/sync_provider.dart';
import 'features/telemetry/presentation/telemetry_provider.dart';

class StorylingoApp extends ConsumerStatefulWidget {
  const StorylingoApp({super.key});

  @override
  ConsumerState<StorylingoApp> createState() => _StorylingoAppState();
}

class _StorylingoAppState extends ConsumerState<StorylingoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefs = ref.read(userPrefsProvider);
      unawaited(
        ref
            .read(telemetryProvider.notifier)
            .record(
              'app_opened',
              properties: {
                'level': prefs.level.id,
                'onboardingCompleted': prefs.onboardingCompleted,
              },
            ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      final previousUserId = previous?.session?.userId;
      final nextUserId = next.session?.userId;
      if (next.isSignedIn && previousUserId != nextUserId) {
        unawaited(
          ref
              .read(syncControllerProvider.notifier)
              .syncNow(silent: true),
        );
        if (nextUserId != null) {
          unawaited(
            ref
                .read(entitlementControllerProvider.notifier)
                .linkAccount(nextUserId),
          );
        }
      } else if (!next.isSignedIn && previous?.isSignedIn == true) {
        unawaited(
          ref.read(entitlementControllerProvider.notifier).unlinkAccount(),
        );
      }
    });
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Storylingo',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_sidebar.dart';
import '../../account/presentation/auth_provider.dart';
import '../../billing/application/entitlement_provider.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _select(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= AppSizes.wideBreakpoint;
    final compact = width < AppSizes.compactBreakpoint;
    final scheme = Theme.of(context).colorScheme;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            AppSidebar(
              currentIndex: navigationShell.currentIndex,
              onSelect: _select,
              subscriptionActive: ref.watch(isEntitledProvider),
              accountLabel: ref.watch(authControllerProvider).session?.email,
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    if (compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined),
              selectedIcon: Icon(Icons.wb_sunny),
              label: 'Aujourd’hui',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Bibliothèque',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Progrès',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.85,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Icon(Icons.auto_stories, color: scheme.primary),
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Réglages',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings'),
                  ),
                  IconButton(
                    tooltip: 'Compte',
                    icon: const Icon(Icons.person_outline),
                    onPressed: () => context.push('/account'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.wb_sunny_outlined),
                  selectedIcon: Icon(Icons.wb_sunny),
                  label: Text('Aujourd’hui'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: Text('Bibliothèque'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: Text('Progrès'),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

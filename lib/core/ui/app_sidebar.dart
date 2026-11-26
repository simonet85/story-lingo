import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    required this.currentIndex,
    required this.onSelect,
    required this.subscriptionActive,
    this.accountLabel,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool subscriptionActive;
  final String? accountLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: AppSizes.sidebarWidth,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                    child: Icon(
                      Icons.auto_stories,
                      size: 20,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Storylingo',
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Column(
                children: [
                  _SidebarItem(
                    icon: Icons.wb_sunny_outlined,
                    selectedIcon: Icons.wb_sunny,
                    label: 'Aujourd’hui',
                    selected: currentIndex == 0,
                    onTap: () => onSelect(0),
                  ),
                  _SidebarItem(
                    icon: Icons.menu_book_outlined,
                    selectedIcon: Icons.menu_book,
                    label: 'Bibliothèque',
                    selected: currentIndex == 1,
                    onTap: () => onSelect(1),
                  ),
                  _SidebarItem(
                    icon: Icons.insights_outlined,
                    selectedIcon: Icons.insights,
                    label: 'Progrès',
                    selected: currentIndex == 2,
                    onTap: () => onSelect(2),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                children: [
                  _SidebarItem(
                    icon: Icons.settings_outlined,
                    label: 'Réglages',
                    onTap: () => context.push('/settings'),
                  ),
                  _SidebarItem(
                    icon: Icons.person_outline,
                    label: 'Compte',
                    subtitle: accountLabel ?? 'Se connecter',
                    onTap: () => context.push('/account'),
                  ),
                  _SidebarItem(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Abonnement',
                    trailing: subscriptionActive ? 'Actif' : 'Offres',
                    trailingAccent: subscriptionActive,
                    onTap: () => context.push('/paywall'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selectedIcon,
    this.selected = false,
    this.subtitle,
    this.trailing,
    this.trailingAccent = false,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final String? subtitle;
  final String? trailing;
  final bool trailingAccent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: AppRadii.buttonBorder,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.buttonBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? (selectedIcon ?? icon) : icon,
                    size: 20,
                    color: foreground,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: selected ? foreground : scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      trailing!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: trailingAccent
                            ? scheme.secondary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'empty_state.dart';

class ActivityEntry {
  const ActivityEntry({
    required this.icon,
    required this.title,
    required this.detail,
    required this.at,
  });

  final IconData icon;
  final String title;
  final String detail;
  final DateTime at;
}

String formatRelativeActivity(DateTime at, DateTime now) {
  final localAt = at.toLocal();
  final localNow = now.toLocal();
  final difference = localNow.difference(localAt);
  if (difference.isNegative || difference.inMinutes < 1) {
    return 'À l’instant';
  }
  if (difference.inMinutes < 60) {
    return 'il y a ${difference.inMinutes} min';
  }
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final day = DateTime(localAt.year, localAt.month, localAt.day);
  final dayGap = today.difference(day).inDays;
  if (dayGap == 0) {
    return 'il y a ${difference.inHours} h';
  }
  if (dayGap == 1) return 'hier';
  if (dayGap < 7) return 'il y a $dayGap j';
  return 'le ${day.day.toString().padLeft(2, '0')}/'
      '${day.month.toString().padLeft(2, '0')}';
}

class ActivityTable extends StatelessWidget {
  const ActivityTable({
    required this.rows,
    this.now,
    this.emptyTitle = 'Aucune activité récente',
    this.emptyMessage =
        'Terminez un chapitre ou une révision pour la voir apparaître ici.',
    super.key,
  });

  final List<ActivityEntry> rows;
  final DateTime? now;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.history,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    final reference = now ?? DateTime.now();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      rows[index].icon,
                      size: 18,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[index].title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rows[index].detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatRelativeActivity(rows[index].at, reference),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

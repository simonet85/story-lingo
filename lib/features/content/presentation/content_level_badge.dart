import 'package:material_ui/material_ui.dart';

class ContentLevelBadge extends StatelessWidget {
  const ContentLevelBadge({required this.level, super.key});

  final String level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        level,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

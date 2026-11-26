import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    required this.title,
    required this.seed,
    this.compact = false,
    super.key,
  });

  final String title;
  final String seed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final index = seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 4;
    final (background, foreground) = switch (index) {
      0 => (scheme.primary, scheme.onPrimary),
      1 => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      2 => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaler = MediaQuery.textScalerOf(context);
          var style =
              (compact
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.titleLarge)!
                  .copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  );
          final iconSize = compact ? 14.0 : 16.0;

          // Shrink until the longest word fits on one line: Flutter would
          // otherwise break words mid-way when the cover is narrow.
          final longestWord = title
              .toUpperCase()
              .split(' ')
              .reduce((a, b) => a.length >= b.length ? a : b);
          final probe = TextPainter(
            text: TextSpan(text: longestWord, style: style),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout();
          if (probe.width > constraints.maxWidth) {
            style = style.copyWith(
              fontSize: (style.fontSize! * constraints.maxWidth / probe.width)
                  .clamp(9.0, style.fontSize!),
            );
          }

          final lineHeight =
              scaler.scale(style.fontSize!) * (style.height ?? 1.3);
          final textHeight =
              constraints.maxHeight - iconSize - AppSpacing.xs - 2;
          final maxLines = constraints.hasBoundedHeight
              ? (textHeight / lineHeight).floor().clamp(1, compact ? 4 : 3)
              : compact
              ? 4
              : 3;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.auto_stories,
                  size: iconSize,
                  color: foreground.withValues(alpha: 0.85),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

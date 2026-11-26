import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({required this.value, this.height = 6, super.key});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.pillBorder,
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
      ),
    );
  }
}

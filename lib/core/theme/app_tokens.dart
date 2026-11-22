import 'package:material_ui/material_ui.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadii {
  static const double card = 20;
  static const double button = 14;
  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius buttonBorder = BorderRadius.all(
    Radius.circular(button),
  );
}

abstract final class AppSizes {
  static const double minTouchTarget = AppSpacing.xxl;
  static const double primaryActionHeight = 52;
  static const double contentMaxWidth = 560;
  static const int coreSessionMinutes = 10;
}

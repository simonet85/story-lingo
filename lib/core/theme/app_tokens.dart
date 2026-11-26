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
  static const double cardLarge = 24;
  static const double button = 14;
  static const double pill = 999;
  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius cardLargeBorder = BorderRadius.all(
    Radius.circular(cardLarge),
  );
  static const BorderRadius buttonBorder = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius pillBorder = BorderRadius.all(
    Radius.circular(pill),
  );
}

abstract final class AppSizes {
  static const double minTouchTarget = AppSpacing.xxl;
  static const double primaryActionHeight = 52;
  static const double contentMaxWidth = 560;
  static const double tabContentMaxWidth = 720;
  static const double readingMaxWidth = 680;
  static const double sidebarWidth = 248;
  static const double compactBreakpoint = 720;
  static const double wideBreakpoint = 960;
  static const int coreSessionMinutes = 10;
  static const int masteredReviewCount = 3;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 220);
}

abstract final class AppColors {
  static const Color seed = Color(0xFF2F5D50);

  // Light — cream paper under daylight.
  static const Color creamSurface = Color(0xFFF7F1E6);
  static const Color cardLight = Color(0xFFFFFCF5);
  static const Color ink = Color(0xFF1B1F1D);
  static const Color amberInk = Color(0xFF8A5A16);
  static const Color amberFill = Color(0xFFE4A23C);

  // Dark — ink page at night.
  static const Color inkSurface = Color(0xFF101614);
  static const Color cardDark = Color(0xFF161D1A);
  static const Color amberLight = Color(0xFFE9B45F);
}

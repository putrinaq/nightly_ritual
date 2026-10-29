import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Colour tokens. One cool ink family for surfaces and greys, one warm
/// candlelight accent, one muted coral reserved for destructive actions.
abstract final class AppColors {
  static const ink = Color(0xFF07080B);
  static const inkRaised = Color(0xFF0E1016);
  static const inkSheet = Color(0xFF12151C);

  static const text = Color(0xFFEDEBE5);
  static const textSecondary = Color(0xFF9A9EAA);
  static const textTertiary = Color(0xFF636875);
  static const hairline = Color(0x14FFFFFF); // white 8%

  static const accent = Color(0xFFE7C894); // candlelight
  static const accentDeep = Color(0xFFC9A66B);
  static const onAccent = Color(0xFF1A1408);

  static const moonlight = Color(0xFFC8D2E6); // only used for light, never UI chrome
  static const moonSurface = Color(0xFFF0EBDD);

  static const danger = Color(0xFFE0806F);

  static Color accentTint([double a = 0.12]) => accent.withValues(alpha: a);
  static Color white(double a) => Colors.white.withValues(alpha: a);
}

/// Motion tokens. Strong custom curves; UI motion stays under ~300ms,
/// rare moments (reveals, the seal) may run longer.
abstract final class Motion {
  static const easeOut = Cubic(0.23, 1, 0.32, 1);
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const drawer = Cubic(0.32, 0.72, 0, 1);

  static const press = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const reveal = Duration(milliseconds: 620);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

abstract final class AppType {
  static const serif = 'InstrumentSerif';
  static const sans = 'Geist';
  static const tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontFamily: serif,
    fontSize: 44,
    height: 1.0,
    letterSpacing: -0.6,
    color: AppColors.text,
  );

  static const title = TextStyle(
    fontFamily: serif,
    fontSize: 34,
    height: 1.05,
    letterSpacing: -0.4,
    color: AppColors.text,
  );

  static const heading = TextStyle(
    fontFamily: serif,
    fontSize: 26,
    height: 1.15,
    letterSpacing: -0.2,
    color: AppColors.text,
  );

  static const body = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 1.45,
    letterSpacing: -0.1,
    color: AppColors.text,
  );

  static const bodyStrong = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.15,
    color: AppColors.text,
  );

  static const secondary = TextStyle(
    fontFamily: sans,
    fontSize: 13.5,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const caption = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    height: 1.3,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );

  static const number = TextStyle(
    fontFamily: sans,
    fontSize: 30,
    height: 1.0,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.8,
    color: AppColors.text,
    fontFeatures: tabular,
  );
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 30.0;
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: AppType.sans,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    canvasColor: AppColors.ink,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      surface: AppColors.inkRaised,
      onSurface: AppColors.text,
      error: AppColors.danger,
    ),
    // Press-scale feedback replaces ink ripples everywhere.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textTheme: base.textTheme.apply(
      fontFamily: AppType.sans,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accentTint(0.3),
      selectionHandleColor: AppColors.accent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1A1E27),
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      contentTextStyle: AppType.body.copyWith(fontSize: 14),
      actionTextColor: AppColors.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.hairline),
      ),
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.accent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

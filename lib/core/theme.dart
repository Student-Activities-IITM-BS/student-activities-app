import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:student_activities/core/app_preferences.dart';

class AppTheme {
  AppTheme._();

  static const primaryColor = Color(0xFF006B5E);
  static const secondaryColor = Color(0xFF285EA8);
  static const backgroundColor = Color(0xFF101416);
  static const surfaceColor = Color(0xFF1A2023);
  static const cardColor = Color(0xFF1A2023);
  static const accentGreen = Color(0xFF1B7F45);
  static const accentAmber = Color(0xFFB05D00);
  static const accentRed = Color(0xFFBA1A1A);
  static const textPrimary = Color(0xFFF2F5F3);
  static const textSecondary = Color(0xFFBEC9C4);
  static const borderColor = Color(0xFF3E4945);

  static ThemeData lightTheme(
    AppVisualStyle style, {
    bool predictiveBack = true,
  }) => _build(
    brightness: Brightness.light,
    style: style,
    predictiveBack: predictiveBack,
  );

  static ThemeData darkThemeFor(
    AppVisualStyle style, {
    bool predictiveBack = true,
  }) => _build(
    brightness: Brightness.dark,
    style: style,
    predictiveBack: predictiveBack,
  );

  static ThemeData get darkTheme =>
      darkThemeFor(AppVisualStyle.material, predictiveBack: true);

  static ThemeData _build({
    required Brightness brightness,
    required AppVisualStyle style,
    required bool predictiveBack,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = style == AppVisualStyle.uix
        ? _uixScheme(brightness)
        : ColorScheme.fromSeed(
            seedColor: const Color(0xFF006B5E),
            brightness: brightness,
            dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          ).copyWith(
            error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
          );
    final isUix = style == AppVisualStyle.uix;
    final radius = isUix ? 24.0 : 12.0;
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isUix ? scheme.surface : scheme.surfaceContainer,
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isUix ? scheme.surface : scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: isUix ? 0 : 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: isUix ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: isUix ? scheme.surfaceContainer : scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 4),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isUix
            ? scheme.surfaceContainer
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius + 8)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: isUix ? 72 : 80,
        backgroundColor: isUix ? Colors.transparent : scheme.surfaceContainer,
        indicatorColor: isUix
            ? scheme.primary.withValues(alpha: isDark ? 0.24 : 0.14)
            : scheme.secondaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isUix ? scheme.surface : scheme.surfaceContainer,
        indicatorColor: isUix
            ? scheme.primary.withValues(alpha: isDark ? 0.24 : 0.14)
            : scheme.secondaryContainer,
        useIndicator: true,
        labelType: NavigationRailLabelType.all,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isUix ? 14 : radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          foregroundColor: scheme.primary,
          backgroundColor: isUix ? scheme.surfaceContainerHigh : null,
          side: isUix ? BorderSide.none : null,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isUix ? 14 : radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isUix ? 14 : radius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isUix ? Colors.white : scheme.onPrimary;
          }
          return isUix ? scheme.surfaceContainerHighest : scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return isUix
              ? scheme.onSurfaceVariant.withValues(alpha: isDark ? 0.34 : 0.24)
              : scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStatePropertyAll(
          isUix ? Colors.transparent : scheme.outlineVariant,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(0),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isUix ? 6 : 3),
        ),
        side: BorderSide(color: scheme.outline),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outline,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isUix
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isUix ? 12 : 8),
        ),
        labelStyle: textTheme.labelLarge,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isUix ? 14 : 22),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: isUix ? FontWeight.w500 : FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            isUix ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
          ),
          elevation: const WidgetStatePropertyAll(0),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.72)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isUix ? 18 : 12),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isUix ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isUix ? 18 : 12),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isUix
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.35 : 0.55,
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: predictiveBack
              ? const PredictiveBackPageTransitionsBuilder()
              : const FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ColorScheme _uixScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2B78E4),
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
    if (isDark) {
      return base.copyWith(
        primary: const Color(0xFFAAC7FF),
        onPrimary: const Color(0xFF00315F),
        primaryContainer: const Color(0xFF004A91),
        onPrimaryContainer: const Color(0xFFD9E8FF),
        secondary: const Color(0xFFBBC7DB),
        tertiary: const Color(0xFF83D5CF),
        error: const Color(0xFFFFB4AB),
        surface: const Color(0xFF111315),
        onSurface: const Color(0xFFE2E7EC),
        surfaceContainerLowest: const Color(0xFF0C0E10),
        surfaceContainerLow: const Color(0xFF191C1F),
        surfaceContainer: const Color(0xFF1D2024),
        surfaceContainerHigh: const Color(0xFF24282C),
        surfaceContainerHighest: const Color(0xFF2B3035),
        onSurfaceVariant: const Color(0xFFC3C7CE),
        outline: const Color(0xFF8D9199),
        outlineVariant: const Color(0xFF42474E),
      );
    }
    return base.copyWith(
      primary: const Color(0xFF1269D3),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFD9E8FF),
      onPrimaryContainer: const Color(0xFF001B3E),
      secondary: const Color(0xFF525F73),
      tertiary: const Color(0xFF006A67),
      error: const Color(0xFFBA1A1A),
      surface: const Color(0xFFF6F7F9),
      onSurface: const Color(0xFF191C20),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF0F2F5),
      surfaceContainer: const Color(0xFFECEEF2),
      surfaceContainerHigh: const Color(0xFFE6E9ED),
      surfaceContainerHighest: const Color(0xFFE0E3E8),
      onSurfaceVariant: const Color(0xFF42474F),
      outline: const Color(0xFF737780),
      outlineVariant: const Color(0xFFC2C7D0),
    );
  }

  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'UPCOMING':
      case 'PLANNED':
        return secondaryColor;
      case 'ONGOING':
        return accentGreen;
      case 'COMPLETED':
        return textSecondary;
      case 'CANCELLED':
      case 'REJECTED':
        return accentRed;
      default:
        return textSecondary;
    }
  }

  static Color categoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'HOUSE':
        return primaryColor;
      case 'SOCIETY':
        return secondaryColor;
      case 'PARADOX':
        return accentAmber;
      default:
        return textSecondary;
    }
  }
}

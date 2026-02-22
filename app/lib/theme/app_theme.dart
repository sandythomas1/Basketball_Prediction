import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App color constants matching the mockup design
class AppColors {
  // Dark theme colors
  static const Color darkBgPrimary = Color(0xFF0d1117);
  static const Color darkBgSecondary = Color(0xFF161b22);
  static const Color darkBgCard = Color(0xFF21262d);
  static const Color darkBgCardHover = Color(0xFF30363d);
  static const Color darkBorder = Color(0xFF30363d);
  static const Color darkTextPrimary = Color(0xFFf0f6fc);
  static const Color darkTextSecondary = Color(0xFF8b949e);
  static const Color darkTextMuted = Color(0xFF6e7681);

  // Light theme colors
  static const Color lightBgPrimary = Color(0xFFffffff);
  static const Color lightBgSecondary = Color(0xFFf6f8fa);
  static const Color lightBgCard = Color(0xFFffffff);
  static const Color lightBgCardHover = Color(0xFFf3f4f6);
  static const Color lightBorder = Color(0xFFd0d7de);
  static const Color lightTextPrimary = Color(0xFF24292f);
  static const Color lightTextSecondary = Color(0xFF57606a);
  static const Color lightTextMuted = Color(0xFF8b949e);

  // Accent colors (same for both themes)
  static const Color accentOrange = Color(0xFF00D4CC);
  static const Color accentYellow = Color(0xFF2563EB);
  static const Color accentBlue = Color(0xFF58a6ff);
  static const Color accentGreen = Color(0xFF3fb950);
  static const Color accentPurple = Color(0xFFbc8cff);
  static const Color liveRed = Color(0xFFf85149);
  static const Color errorRed = Color(0xFFf85149);
}

/// Custom text styles using Google Fonts
class AppTextStyles {
  static TextStyle get dmSans => GoogleFonts.dmSans();
  static TextStyle get spaceMono => GoogleFonts.spaceMono();

  // Heading styles
  static TextStyle heading1(Color color) => GoogleFonts.dmSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle heading2(Color color) => GoogleFonts.dmSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle heading3(Color color) => GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Body styles
  static TextStyle bodyLarge(Color color) => GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodyMedium(Color color) => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodySmall(Color color) => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // Label styles
  static TextStyle labelLarge(Color color) => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle labelMedium(Color color) => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle labelSmall(Color color) => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      );

  // Monospace styles (for dates, stats, etc.)
  static TextStyle monoLarge(Color color) => GoogleFonts.spaceMono(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle monoMedium(Color color) => GoogleFonts.spaceMono(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle monoSmall(Color color) => GoogleFonts.spaceMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle monoLabel(Color color) => GoogleFonts.spaceMono(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 1.5,
      );
}

/// App theme configuration
class AppTheme {
  /// Dark theme matching the mockup design
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBgPrimary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accentOrange,
      secondary: AppColors.accentBlue,
      tertiary: AppColors.accentYellow,
      surface: AppColors.darkBgSecondary,
      error: AppColors.errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
      onError: Colors.white,
      outline: AppColors.darkBorder,
      surfaceContainerHighest: AppColors.darkBgCard,
    ),
    textTheme: _buildTextTheme(AppColors.darkTextPrimary),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBgSecondary,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.darkTextSecondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkBgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkBgPrimary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 2),
      ),
      labelStyle: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.darkTextSecondary,
      ),
      hintStyle: GoogleFonts.dmSans(
        fontSize: 16,
        color: AppColors.darkTextMuted,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkTextPrimary,
        side: const BorderSide(color: AppColors.darkBorder, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accentBlue,
        textStyle: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkBgSecondary,
      indicatorColor: AppColors.accentOrange.withOpacity(0.1),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.accentOrange,
          );
        }
        return GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.accentOrange);
        }
        return const IconThemeData(color: AppColors.darkTextSecondary);
      }),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkBgCard,
      contentTextStyle: GoogleFonts.dmSans(
        color: AppColors.darkTextPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

  /// Light theme variant
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBgPrimary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accentOrange,
      secondary: AppColors.accentBlue,
      tertiary: AppColors.accentYellow,
      surface: AppColors.lightBgSecondary,
      error: AppColors.errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
      onError: Colors.white,
      outline: AppColors.lightBorder,
      surfaceContainerHighest: AppColors.lightBgCard,
    ),
    textTheme: _buildTextTheme(AppColors.lightTextPrimary),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightBgSecondary,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.lightTextPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.lightTextSecondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightBgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightBgPrimary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 2),
      ),
      labelStyle: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.lightTextSecondary,
      ),
      hintStyle: GoogleFonts.dmSans(
        fontSize: 16,
        color: AppColors.lightTextMuted,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.lightTextPrimary,
        side: const BorderSide(color: AppColors.lightBorder, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accentBlue,
        textStyle: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.lightBgSecondary,
      indicatorColor: AppColors.accentOrange.withOpacity(0.1),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.accentOrange,
          );
        }
        return GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.accentOrange);
        }
        return const IconThemeData(color: AppColors.lightTextSecondary);
      }),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.lightBgCard,
      contentTextStyle: GoogleFonts.dmSans(
        color: AppColors.lightTextPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

  static TextTheme _buildTextTheme(Color textColor) {
    return TextTheme(
      displayLarge: GoogleFonts.dmSans(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      displaySmall: GoogleFonts.dmSans(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      headlineLarge: GoogleFonts.dmSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textColor,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Extension for easy access to custom colors from context
extension ThemeExtensions on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get bgPrimary =>
      isDarkMode ? AppColors.darkBgPrimary : AppColors.lightBgPrimary;
  Color get bgSecondary =>
      isDarkMode ? AppColors.darkBgSecondary : AppColors.lightBgSecondary;
  Color get bgCard => isDarkMode ? AppColors.darkBgCard : AppColors.lightBgCard;
  Color get bgCardHover =>
      isDarkMode ? AppColors.darkBgCardHover : AppColors.lightBgCardHover;
  Color get borderColor =>
      isDarkMode ? AppColors.darkBorder : AppColors.lightBorder;
  Color get textPrimary =>
      isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary =>
      isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textMuted =>
      isDarkMode ? AppColors.darkTextMuted : AppColors.lightTextMuted;
}



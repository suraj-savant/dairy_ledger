import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App theme adhering to Section 4 Design Principles:
/// - Tap targets at least 56dp
/// - Body text at least 16sp
/// - Milk-white background (#FDFBF7)
/// - Deep purple primary (#4527A0)
/// - Amber highlights (#FFB300)
/// - Material 3 design
/// - Layouts fit with phone font size set to 130%
class AppTheme {
  AppTheme._();

  // Primary colors
  static const Color milkWhite = Color(0xFFFDFBF7);
  static const Color deepPurple = Color(0xFF4527A0);
  static const Color deepPurpleLight = Color(0xFF673AB7);
  static const Color deepPurpleDark = Color(0xFF311B92);
  static const Color deepPurpleContainer = Color(0xFFE6DEFF);

  // Accent colors
  static const Color amberHighlight = Color(0xFFFFB300);
  static const Color amberContainer = Color(0xFFFFF0C2);

  // Surface and text colors
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF211B2B);
  static const Color textSecondary = Color(0xFF625B71);
  static const Color outlineColor = Color(0xFFCAC4D0);
  static const Color errorRed = Color(0xFFBA1A1A);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,

      // Primary palette
      primary: deepPurple,
      onPrimary: Colors.white,
      primaryContainer: deepPurpleContainer,
      onPrimaryContainer: Color(0xFF21005D),

      // Secondary palette
      secondary: amberHighlight,
      onSecondary: Color(0xFF2A1800),
      secondaryContainer: amberContainer,
      onSecondaryContainer: Color(0xFF2A1800),

      // Surface palette
      surface: surfaceColor,
      onSurface: textPrimary,

      // Error palette
      error: errorRed,
      onError: Colors.white,

      // Outlines and variants
      outline: outlineColor,
      outlineVariant: Color(0xFFE5DFEB),

      // Additional Material 3 colors
      tertiary: Color(0xFF7D5260),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFD8E4),
      onTertiaryContainer: Color(0xFF31101D),

      surfaceContainerHighest: Color(0xFFF0EBF5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: milkWhite,

      // Typography
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),

      // App bar
      appBarTheme: const AppBarTheme(
        backgroundColor: deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 24,
        ),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: deepPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: deepPurple,
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          side: const BorderSide(
            color: deepPurple,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: deepPurple,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFE5DFEB),
            width: 1,
          ),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: outlineColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: outlineColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: deepPurple,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: errorRed,
          ),
        ),
        labelStyle: const TextStyle(
          fontSize: 16,
          color: textSecondary,
        ),
        hintStyle: const TextStyle(
          fontSize: 16,
          color: Color(0xFF8A8494),
        ),
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: deepPurple,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Material 3 navigation bar (Home | Rates | Analytics, Morning | Evening)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: deepPurpleContainer,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected) ? deepPurple : textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 14,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.bold
                : FontWeight.normal,
            color: states.contains(WidgetState.selected) ? deepPurple : textSecondary,
          ),
        ),
      ),

      // Tabs (Morning | Evening)
      tabBarTheme: const TabBarThemeData(
        labelColor: deepPurple,
        unselectedLabelColor: textSecondary,
        indicatorColor: deepPurple,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Color(0xFFE5DFEB),
        labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontSize: 16),
      ),

      // Snack bars float above the bottom bars
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(fontSize: 16, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5DFEB),
        space: 1,
        thickness: 1,
      ),

      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        subtitleTextStyle: TextStyle(fontSize: 16, color: textSecondary),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: deepPurple),

      // Floating action button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: deepPurple,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          color: textSecondary,
        ),
      ),
    );
  }
}

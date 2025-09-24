import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Manages app theme (light/dark mode) with persistence
class ThemeManager extends ChangeNotifier {
  static ThemeManager? _instance;
  bool _isDarkMode = false;
  static const String _darkModeKey = 'dark_mode_enabled';

  ThemeManager._internal();

  static ThemeManager get I {
    _instance ??= ThemeManager._internal();
    return _instance!;
  }

  bool get isDarkMode => _isDarkMode;

  /// Initialize theme manager by loading saved preference
  Future<void> init() async {
    try {
      await db.initialize();
      _isDarkMode = await db.getBool(_darkModeKey, defaultValue: false);
      notifyListeners();
    } catch (e) {
      // Default to light mode if loading fails
      _isDarkMode = false;
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    try {
      await db.setBool(_darkModeKey, _isDarkMode);
    } catch (e) {
      // If saving fails, we'll still keep the UI change
      // but it won't persist across app restarts
    }
  }

  /// Set specific theme mode
  Future<void> setDarkMode(bool isDark) async {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      notifyListeners();

      try {
        await db.setBool(_darkModeKey, _isDarkMode);
      } catch (e) {
        // If saving fails, we'll still keep the UI change
        // but it won't persist across app restarts
      }
    }
  }

  /// Get light theme with neumorphic design
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFC049), // warm yellow seed
        brightness: Brightness.light,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFC049),
          foregroundColor: const Color(0xFF3C3C3C),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF5A4A00),
          side: const BorderSide(color: Color(0xFFFFC049), width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F5F5),
        foregroundColor: Color(0xFF3C3C3C),
        elevation: 0,
      ),
    );
  }

  /// Get dark theme with neumorphic design adapted for dark mode
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000), // Pure black background like the design
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFC049), // same warm yellow seed
        brightness: Brightness.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFC049),
          foregroundColor: const Color(0xFF1E1E1E), // darker text for contrast
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFC049),
          side: const BorderSide(color: Color(0xFFFFC049), width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000), // Match the black background
        foregroundColor: Color(0xFFE0E0E0),
        elevation: 0,
      ),
      // Add custom switch theme for better dark mode appearance
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFFFFC049); // Use accent color when on
          }
          return const Color(0xFF9E9E9E); // Grey when off
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFFFFC049).withOpacity(0.3); // Accent with opacity when on
          }
          return const Color(0xFF424242); // Dark grey when off
        }),
        overlayColor: MaterialStateProperty.all(Colors.transparent),
      ),
    );
  }

  /// Get current theme based on mode
  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  /// Get neumorphic container colors for current theme
  List<Color> get neumorphicGradient => _isDarkMode
    ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]  // iOS-style dark mode cards - lighter grey for contrast against black
    : [const Color(0xFFFDFDFD), const Color(0xFFE3E3E3)]; // Light neumorphic

  /// Get neumorphic shadow colors for current theme
  List<BoxShadow> get neumorphicShadows => _isDarkMode
    ? [
        const BoxShadow(offset: Offset(0, 4), blurRadius: 20, color: Color(0x40000000)), // Subtle shadow against black
        const BoxShadow(offset: Offset(0, 1), blurRadius: 6, color: Color(0x10FFFFFF)), // Very subtle inner light
      ]
    : [
        const BoxShadow(offset: Offset(6, 6), blurRadius: 18, color: Color(0x1F000000)),
        const BoxShadow(offset: Offset(-6, -6), blurRadius: 18, color: Color(0x88FFFFFF)),
      ];

  /// Get primary text color for current theme
  Color get primaryTextColor => _isDarkMode
    ? const Color(0xFFFFFFFF) // Pure white for better contrast against grey cards
    : const Color(0xFF2F2F2F);

  /// Get secondary text color for current theme
  Color get secondaryTextColor => _isDarkMode
    ? const Color(0xFFE0E0E0) // Lighter grey for better readability
    : const Color(0xFF5A5A5A);

  /// Get tertiary text color for current theme (for subtle elements)
  Color get tertiaryTextColor => _isDarkMode
    ? const Color(0xFF888888)
    : const Color(0xFF888888);

  /// Get background color for info containers
  Color get infoBackgroundColor => _isDarkMode
    ? const Color(0xFF2A2A2A)
    : const Color(0xFFFFF8F0);

  /// Get elevated surface color (for cards that should stand out)
  Color get elevatedSurfaceColor => _isDarkMode
    ? const Color(0xFF2C2C2E) // Match the new card color
    : const Color(0xFFFFFFFF);

  /// Get card border color for subtle separation
  Color get cardBorderColor => _isDarkMode
    ? const Color(0xFF404040)
    : const Color(0xFFE0E0E0);

  /// Get disabled element color
  Color get disabledColor => _isDarkMode
    ? const Color(0xFF444444)
    : const Color(0xFFD4D4D4);

  /// Get success/active indicator color
  Color get successColor => _isDarkMode
    ? const Color(0xFF4CAF50)
    : const Color(0xFF4CAF50);

  /// Get error/warning indicator color
  Color get errorColor => _isDarkMode
    ? const Color(0xFFEF5350)
    : const Color(0xFFEF5350);

  /// Get warning color
  Color get warningColor => _isDarkMode
    ? const Color(0xFFFF9800)
    : const Color(0xFFFF9800);

  /// Get accent color variants for dark mode
  Color get accentColorDark => const Color(0xFFFFB347); // Slightly warmer for dark backgrounds
  Color get accentColorLight => const Color(0xFFFFC049); // Original warm yellow

  /// Get current accent color based on theme
  Color get currentAccentColor => _isDarkMode ? accentColorDark : accentColorLight;

  /// Get navigation bar colors
  Color get navigationBarColor => _isDarkMode
    ? const Color(0xFF000000) // Match the black background
    : Colors.white;

  /// Get navigation bar shadow
  List<BoxShadow> get navigationBarShadow => _isDarkMode
    ? [const BoxShadow(color: Color(0x30000000), blurRadius: 10, spreadRadius: 1)]
    : [const BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)];

  /// Get app bar elevation color
  Color get appBarElevationColor => _isDarkMode
    ? const Color(0xFF2A2A2A)
    : const Color(0xFFF5F5F5);

  /// Get modal/sheet background color
  Color get sheetBackgroundColor => _isDarkMode
    ? const Color(0xFF1C1C1E) // Darker grey for sheets
    : const Color(0xFFD0CECE);

  /// Get divider color
  Color get dividerColor => _isDarkMode
    ? const Color(0xFF383838)
    : const Color(0xFFE0E0E0);
}
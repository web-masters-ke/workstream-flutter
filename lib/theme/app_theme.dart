import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

/// Brand palette for WorkStream — professional workforce app.
///
/// Primary: deep navy. Accent: teal. Warn: amber. Danger: crimson.
class AppColors {
  // Brand
  static const primary = Color(0xFF0F2A47); // deep navy
  static const primaryDeep = Color(0xFF081A2E);
  static const primarySoft = Color(0xFF1D3E63);
  static const accent = Color(0xFF14B8A6); // teal-500
  static const accentDeep = Color(0xFF0E8F81);
  static const warn = Color(0xFFF59E0B); // amber-500
  static const danger = Color(0xFFDC2626); // red-600
  static const success = Color(0xFF16A34A); // green-600

  // Dark surfaces
  static const darkBg = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF111A2C);
  static const darkCard = Color(0xFF16233B);
  static const darkBorder = Color(0xFF22314C);
  static const darkText = Color(0xFFF4F6FA);
  static const darkSubtext = Color(0xFF94A3B8);

  // Light surfaces
  static const lightBg = Color(0xFFF4F6FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightText = Color(0xFF0F172A);
  static const lightSubtext = Color(0xFF64748B);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        error: AppColors.danger,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.darkText,
        displayColor: AppColors.darkText,
      ),
      cardColor: AppColors.darkCard,
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      dividerColor: AppColors.darkBorder,
      iconTheme: const IconThemeData(color: AppColors.darkText),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.darkText,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      inputDecorationTheme: _inputTheme(
        fill: AppColors.darkSurface,
        border: AppColors.darkBorder,
        hint: AppColors.darkSubtext,
      ),
      elevatedButtonTheme: _primaryButton(),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.darkSubtext,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.accent, width: 2.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCard,
        contentTextStyle: GoogleFonts.inter(color: AppColors.darkText),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        error: AppColors.danger,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.lightText,
        displayColor: AppColors.lightText,
      ),
      cardColor: AppColors.lightCard,
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      dividerColor: AppColors.lightBorder,
      iconTheme: const IconThemeData(color: AppColors.lightText),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.lightText),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.lightText,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      inputDecorationTheme: _inputTheme(
        fill: AppColors.lightSurface,
        border: AppColors.lightBorder,
        hint: AppColors.lightSubtext,
      ),
      elevatedButtonTheme: _primaryButton(),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.lightSubtext,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primary, width: 2.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static InputDecorationTheme _inputTheme({
    required Color fill,
    required Color border,
    required Color hint,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: GoogleFonts.inter(color: hint),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }

  static ElevatedButtonThemeData _primaryButton() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}

/// Theme controller — persists user preference in SharedPreferences.
class ThemeController extends ChangeNotifier {
  ThemeController() {
    _load();
  }

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(PrefsKeys.theme);
    if (v == 'light') {
      _mode = ThemeMode.light;
    } else if (v == 'system') {
      _mode = ThemeMode.system;
    } else {
      _mode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsKeys.theme,
      _mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsKeys.theme,
      m == ThemeMode.dark
          ? 'dark'
          : m == ThemeMode.light
          ? 'light'
          : 'system',
    );
  }
}

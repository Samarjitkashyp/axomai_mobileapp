import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors matching chat.aiaxom.co.in
  static const Color bgMain = Color(0xFF06060B);
  static const Color bgSidebar = Color(0xFF090A14);
  static const Color bgCard = Color(0xFF0E101F);
  static const Color bgCardHover = Color(0xFF13162B);
  static const Color bgInput = Color(0xFF0E101F);
  static const Color bgPill = Color(0xFF121528);
  static const Color bgPillActive = Color(0xFF1D1B38);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDim = Color(0xFF475569);

  // Accent & Gradients
  static const Color accentPurple = Color(0xFFC084FC);
  static const Color accentPink = Color(0xFFE879F9);
  static const Color accentViolet = Color(0xFFA855F7);
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentBlue = Color(0xFF60A5FA);
  static const Color successGreen = Color(0xFF4ADE80);
  static const Color errorRed = Color(0xFFF87171);

  // Borders
  static const Color borderColor = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color borderFocus = Color(0x80C084FC);
  static const Color borderGlow = Color(0x4DC084FC);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPurple, accentPink],
  );

  static const LinearGradient glowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x59C084FC), Color(0x59E879F9)],
  );

  static const LinearGradient userBubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E1065), Color(0xFF1E1B4B)],
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgMain,
      primaryColor: accentPurple,
      colorScheme: const ColorScheme.dark(
        primary: accentPurple,
        secondary: accentPink,
        surface: bgCard,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
        fontFamilyFallback: const [
          'Inter',
          'Segoe UI',
          'Roboto',
          'Noto Sans Bengali',
          'sans-serif',
        ],
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgMain,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: bgSidebar,
      ),
      dividerColor: borderColor,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      primaryColor: accentPurple,
      colorScheme: const ColorScheme.light(
        primary: accentPurple,
        secondary: accentPink,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: const Color(0xFF0F172A),
        displayColor: const Color(0xFF0F172A),
        fontFamilyFallback: const [
          'Inter',
          'Segoe UI',
          'Roboto',
          'Noto Sans Bengali',
          'sans-serif',
        ],
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
      ),
      dividerColor: const Color(0x14000000),
    );
  }
}

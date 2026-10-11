import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Color Palette - 100% Exact Parity with https://chat.aiaxom.co.in/
  static const Color bgMain = Color(0xFF0B1220); // Deep Obsidian Cyber Navy
  static const Color bgDark = Color(0xFF0B1220);
  static const Color bgSidebar = Color(0xFF090A14); // Deep Night
  static const Color bgCard = Color(0xFF0E101F);
  static const Color bgSurface = Color(0xFF0E101F);
  static const Color bgCardHover = Color(0xFF13162B);
  static const Color bgInput = Color(0xFF0E101F);
  static const Color bgPill = Color(0xFF121528);
  static const Color bgPillActive = Color(0xFF1D1B38);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDim = Color(0xFF475569);

  // Signature Axom AI Brand Accents (Emerald Green & Amber Gold & Cyan)
  static const Color accentEmerald = Color(0xFF34D399); // Brand primary
  static const Color accentAmber = Color(0xFFFBBF24); // Brand secondary
  static const Color accentPurple = Color(0xFF34D399); // Aliased to brand primary
  static const Color accentPink = Color(0xFFFBBF24); // Aliased to brand gold
  static const Color accentViolet = Color(0xFF10B981);
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentBlue = Color(0xFF60A5FA);
  static const Color successGreen = Color(0xFF34D399);
  static const Color errorRed = Color(0xFFF87171);

  // Borders & Glassmorphism
  static const Color borderColor = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color glassBorder = Color(0x14FFFFFF);
  static const Color borderFocus = Color(0x8034D399); // rgba(52, 211, 153, 0.5)
  static const Color borderGlow = Color(0x5934D399); // rgba(52, 211, 153, 0.35)

  // Gradients matching web chat
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFFFBBF24)], // #34d399 -> #fbbf24
  );

  static const LinearGradient brandTextGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFA7F3D0)],
  );

  static const LinearGradient glowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x5934D399), Color(0x59FBBF24)],
  );

  static const RadialGradient orbGradient = RadialGradient(
    colors: [
      Color(0xFF34D399),
      Color(0xFF10B981),
      Color(0xFF14B8A6),
      Color(0xFF0B1220),
    ],
    stops: [0.0, 0.4, 0.8, 1.0],
  );

  static const LinearGradient userBubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF23273A), Color(0xFF1E2235)],
  );

  // Cached Themes for 60/120fps ultra-smooth performance
  static final ThemeData darkTheme = _buildDarkTheme();
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgMain,
      primaryColor: accentEmerald,
      colorScheme: const ColorScheme.dark(
        primary: accentEmerald,
        secondary: accentAmber,
        surface: bgCard,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
        fontFamilyFallback: const [
          'Plus Jakarta Sans',
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

  static ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      primaryColor: accentEmerald,
      colorScheme: const ColorScheme.light(
        primary: accentEmerald,
        secondary: accentAmber,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: const Color(0xFF0F172A),
        displayColor: const Color(0xFF0F172A),
        fontFamilyFallback: const [
          'Plus Jakarta Sans',
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
      dividerColor: const Color(0xFFE2E8F0),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color feltGreen      = Color(0xFF1A472A);
  static const Color feltGreenDark  = Color(0xFF0D2B18);
  static const Color feltGreenLight = Color(0xFF2D6A4F);

  static const Color cardIvory  = Color(0xFFFAF7F0);
  static const Color cardCream  = Color(0xFFF0EBE0);
  static const Color cardBorder = Color(0xFFD0C8B8);

  static const Color gold      = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE8D27B);
  static const Color goldDark  = Color(0xFFAA8820);

  static const Color navy      = Color(0xFF0D1B2A);
  static const Color navyLight = Color(0xFF1B2A3B);

  static const Color diceRed   = Color(0xFFC62828);
  static const Color diceBlue  = Color(0xFF1565C0);

  static const Color success = Color(0xFF2E7D32);
  static const Color danger  = Color(0xFFC62828);
  static const Color warn    = Color(0xFFE65100);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient feltGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [feltGreen, feltGreenDark],
  );

  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyLight, navy],
  );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1565C0), Color(0xFF6A1B9A)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDark],
  );

  static const LinearGradient diceIvoryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardIvory, Color(0xFFEDE8DC)],
  );

  // ── Typography ───────────────────────────────────────────────────────────
  /// Cinzel — for titles, game names, round headers
  static TextStyle display({
    double size = 32,
    Color color = Colors.white,
    FontWeight weight = FontWeight.bold,
    double spacing = 1.5,
  }) =>
      GoogleFonts.cinzel(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
      );

  /// Cinzel — for sub-headings
  static TextStyle heading({
    double size = 18,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w600,
  }) =>
      GoogleFonts.cinzel(fontSize: size, fontWeight: weight, color: color);

  // ── Decorations ──────────────────────────────────────────────────────────
  static BoxDecoration card({
    Color color = cardIvory,
    double radius = 16,
    bool elevated = true,
    Color? borderColor,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? cardBorder, width: 1.5),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Color(0x22FFFFFF),
                  blurRadius: 2,
                  offset: Offset(0, -1),
                ),
              ]
            : null,
      );

  static BoxDecoration goldPanel({double radius = 12}) => BoxDecoration(
        gradient: goldGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55D4AF37),
            blurRadius: 14,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
      );

  static BoxDecoration navyPanel({double radius = 12}) => BoxDecoration(
        gradient: navyGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: gold.withValues(alpha: 0.3), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      );

  // ── Material ThemeData ───────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        scaffoldBackgroundColor: cardCream,
        appBarTheme: AppBarTheme(
          backgroundColor: navyLight,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.cinzel(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 1,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textTheme: GoogleFonts.nunitoTextTheme(),
      );
}

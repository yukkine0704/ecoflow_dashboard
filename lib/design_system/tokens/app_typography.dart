import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme buildAppTextTheme(Brightness brightness) {
  final bodyColor = brightness == Brightness.dark
      ? const Color(0xFFF3F6F5)
      : const Color(0xFF353328);
  final mutedColor = brightness == Brightness.dark
      ? const Color(0xFFD2D8D7)
      : const Color(0xFF625F53);

  return TextTheme(
    displayLarge: GoogleFonts.spaceGrotesk(
      fontSize: 56,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      height: 1.0,
      color: bodyColor,
    ),
    headlineMedium: GoogleFonts.spaceGrotesk(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.1,
      color: bodyColor,
    ),
    titleLarge: GoogleFonts.manrope(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
      height: 1.2,
      color: bodyColor,
    ),
    bodyMedium: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: bodyColor,
    ),
    labelSmall: GoogleFonts.manrope(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      height: 1.3,
      color: mutedColor,
    ),
  );
}

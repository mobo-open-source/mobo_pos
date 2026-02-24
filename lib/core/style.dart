import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A central class defining the application's design system and styling.
class AppStyle {
  /// The primary color used across the application.
  static const Color primaryColor = Color(0xFFC03355);

  /// Generates a [TextStyle] using the Manrope font with optional customizations.
  static TextStyle font({
    double size = 14,
    FontWeight weight = FontWeight.normal,
    Color? color,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}

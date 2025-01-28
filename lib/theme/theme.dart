import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF1A237E); // Deep Indigo
  static const Color secondaryColor =
      Color(0xFF283593); // Slightly lighter Indigo
  static const Color accentColor = Color(0xFF3949AB); // Bright Indigo
  static const Color backgroundColor =
      Color(0xFFF8F9FF); // Light blue-tinted white
  static const Color backgroundGradientStart = Color(0xFFFFFFFF); // Pure white
  static const Color backgroundGradientEnd =
      Color(0xFFF0F2FF); // Very light indigo
  static const Color surfaceColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF1A1F36); // Dark blue-gray
  static const Color textSecondaryColor = Color(0xFF4A5568); // Medium blue-gray
  static const Color cardGradient1 = Color(0xFF3949AB); // Start gradient
  static const Color cardGradient2 = Color(0xFF1A237E); // End gradient
  static const Color statusCardBg = Color(0xFF303F9F); // Status card background

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundGradientStart, backgroundGradientEnd],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardGradient1, cardGradient2],
  );

  // Box Decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Text Styles
  static const TextStyle headlineStyle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textPrimaryColor,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 14,
    color: textSecondaryColor,
  );

  // AppBar Theme
  static AppBarTheme appBarTheme = AppBarTheme(
    elevation: 0,
    backgroundColor: primaryColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(30),
      ),
    ),
    titleTextStyle: headlineStyle,
  );
}

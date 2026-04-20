/*
 * Samuel Bulnes
 * Senior Project
 * constants
 * Colors, Strings, Sizes, etc.
*/

import 'package:flutter/material.dart';

//***********************************************************************************
// App Colors - Dark Theme with Neon Accents
class AppColors {
  // Dark theme primary colors
  static const Color primary = Color(0xFF0A0E27);      // Deep dark blue
  static const Color background = Color(0xFF0F1419);   // Almost black background
  static const Color cardBackground = Color(0xFF1A1F2E); // Dark card background
  static const Color textPrimary = Color(0xFFFFFFFF);  // White text
  static const Color textSecondary = Color(0xFFB0B0B0); // Light gray text
  
  // Neon accent colors
  static const Color neonBlue = Color(0xFF00D9FF);     // Bright cyan neon
  static const Color neonAccent = Color(0xFF00FFFF);   // Electric cyan
  
  // Cards colors (Adjusted for dark theme)
  static const Color pink = Color(0xFFFF006E);
  static const Color orange = Color(0xFFFF6B35);
  static const Color green = Color(0xFF00D977);
  static const Color yellow = Color(0xFFFFD60A);
  static const Color purple = Color(0xFF9D4EDD);
}

//***********************************************************************************
// Strings
class AppStrings {
  static const String appName = 'ORUneed';
  static const String university = 'Oral Roberts University';
  static const String emailDomain = '@oru.edu';
}

//***********************************************************************************
// Size and spaced 
class AppSizes {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
}